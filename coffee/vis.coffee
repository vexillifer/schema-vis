# Explores and visualizes XML data, schema agnostic
# Melsa Smith, Aug 2012
# Peter Beshai, March 2013

class XMLSchema
  constructor: (data) ->

    # default vis style settings
    @config = {
      node_fill: '#8b9dc3',
      node_stroke: '#3b5998',
      node_stroke_width: 2,
      node_radius: 5,
      node_text_style: '',
      line_stroke_width: 1,
      line_stroke: '#aaaaaa',
      line_stroke_opacity: 1,
      show_foci: false,

      cluster_radius_factor: 4
      cluster_radius_offset: 5

      # focused node properties
      focused_radius_offset: 3
      focused_fill: "#FFEFBF"
      focused_stroke: "#FFD04B"

      # performance otions
      static_load: 0,
      expand_circles_on_entry: false,
      node_limit: 300,
      tick_limit: 10, # TODO: set low for faster debugging
    }

    # The history stack
    @history = []
    # The history pointer
    @history_pos = 0

    @width = window.innerWidth
    @height = window.innerHeight
    @data = data

    @zoom_min = .5
    @zoom_max = 4
    @zoom_show_labels = 7/8
    @zoom_hint_labels = 3/4
    zoom_current_tier = 1

    # these parameters completely
    # specify a visualization
    @visibility_map = [] # index maps to node idx, true or false value whether node is visible
    @nodes  = []
    @links  = []
    @foci   = []
    @charge = -500
    @link_distance = 100
    @layout_gravity = 0.1

    #configure clustering type
    @display_modes = { raw: "raw", community: "community", attribute: "attribute" } # enum sort of
    display_modes: @display_modes # make public
    @display_mode = { mode: @display_modes.raw }

    # network data
    @people = []
    @connections = []
    @index  = {}

    @circles = null
    @visualization = null

    @tooltip = CustomTooltip("node_tooltip", 240)
    @center = {x: @width / 2, y: @height / 2}
    @damper = 0.1
    @force = null
    @node_drag = null
    @zoom = null
    @tick_count = 0

    @focused_node = null
    @focused_node_data = null

    # current state
    @current_filter_node_list = null

    @get_colour = d3.scale.category20(); # a function takes in an int and produces a colour string

    if @data.firstChild.nodeName == 'network'
      @explore_network(@data)
      #@viz_default()
    else
      #@explore_data @data, {}
      #@visualize()
      console.error 'Data is not a social network.'

    # save the initial state
    @initial_state = this.history_snapshot(@display_mode, @current_filter_node_list)

  # Compute all nodes and links in network
  # 1) Create a node for each profile
  # 2) Create a link for each connection
  explore_network: (network) =>
    node = {}
    attrs = ['uid','name','sex','locale']

    people = network.firstChild.querySelectorAll('person')
    connections = network.firstChild.querySelectorAll('connection')


    for person, i in people
      if @config.node_limit? and i > @config.node_limit then break
      node = {}
      for attr in person.childNodes
        # look for attribute-esque children
        if attr.firstChild != null and
        attr.firstChild.nodeType == 3 and
        attr.firstChild.nodeValue.trim() != '' and
        attr.nodeName in attrs
          node[attr.nodeName] = attr.firstChild.nodeValue
      copy = $.extend({}, node)
      copy.DOMNodeName = copy.name

      copy.idx = i
      @index[copy.name] = copy
      @people.push(copy)


    for connection in connections
      uid1 = connection.querySelector('uid1').firstChild.nodeValue
      uid2 = connection.querySelector('uid2').firstChild.nodeValue
      @connections.push([uid1, uid2])


  reset: () =>
    @force?.stop()
    @nodes.length = 0
    @foci.length  = 0
    @links.length = 0
    $('#svg_vis').remove()
    @tick_count = 0
    @tooltip.hideTooltip()
    this.clear_selection()

  set_display_mode: (mode, meta, redraw = true) =>
    @history_snapshot(@display_mode, @current_filter_node_list)

    @display_mode = { mode: mode }
    if mode == @display_modes.attribute
      @display_mode.attribute = meta



    if redraw
      this.display(@current_filter_node_list)

  # Take a snapshot of current state,
  # push it on to the history stack
  history_snapshot: (mode, nodes) =>
    frame = {}
    frame.label = ""
    frame.mode  = mode
    frame.nodes = nodes
    frame.ts    = Date.now()
    history.pushState(frame, "", "")
    console.log('Snapshot!')
    return frame

  history_popstate: (e) =>
    console.log('POPSTATE ', e.state)
    if e.state
      @history_go(e.state)

  # Play a history snapshot into
  # current state
  history_go: (frame) =>
    $this = this
    console.log('History: ', frame)
    $('#svg_vis').remove()
    $('#prop_meta').fadeOut()
    @display_mode = frame.mode
    @display(frame.nodes)

  history_reset: () =>
    this.history_go(@initial_state)


  filter: (node_list) =>
    @visibility_map.length = 0
    if node_list?
      for node_idx in node_list
        @visibility_map[node_idx] = true

  # filter node list is an array of nodes that are visible, typically the contents of a cluster
  # if empty, all of @people is used
  display: (filter_node_list) =>
    console.log "display()"
    @reset()
    @current_filter_node_list = filter_node_list
    @foci.push @center

    # entire node list will be @people
    nodes = @people

    # setup the visibility map
    this.filter(filter_node_list)

    # checks if we filtered at all... kind of a lazy way of defaulting to true unless a list is specified,
    # in which case, we default to false. probably not a good idea in the long run.
    is_node_visible = (node) =>
      if node?
        return not filter_node_list? or (filter_node_list? and @visibility_map[node.idx] == true)
      return false

    # circle_x/y: gives the x/y coordinate, positioning items in a circle
    # width/height: half the width/height of the circle
    # circle_const is of the form 2*Math.PI/num_items and i is in [0..num_items-1]
    circle_x = (width, circle_const, i) =>
      @center.x + width * Math.cos(i * circle_const)

    circle_y = (height, circle_const, i) =>
      @center.y + height * Math.sin(i * circle_const)

    # variables for putting the nodes in a circle
    circle_const = 2*Math.PI/nodes.length;
    half_width = @width/2;
    half_height = @height/2;

    # build up set of nodes
    for node, i in nodes
      node.fixed = false # revert pinned behavior

      if is_node_visible node
        node.radius = @config.node_radius
        node.text = ''
        node.DOMNodeName = ''
        node.x = circle_x(half_width, circle_const, i)
        node.y = circle_y(half_height, circle_const, i)
        node.px = node.x
        node.py = node.y

        @nodes.push node

    # build up set of links
    for connection in @connections
      source = @index[connection[0]]
      target = @index[connection[1]]

      if source? and target? and (is_node_visible source) and (is_node_visible target) and source != target
        link = {
          source: source
          target: target
        }
        @links.push link


    # we have nodes and edges, now apply clustering.
    clusters = this.get_clusters(@nodes, @links)

    # create node to cluster map (node.idx -> cluster index)
    node_cluster_map = {}
    for cluster, cluster_index in clusters
      for node_idx in cluster.nodes
        node_cluster_map[node_idx] = cluster_index

    # remove nodes that are in clusters
    @nodes = _.filter(@nodes, (node) -> node_cluster_map[node.idx] == undefined)

    # create cluster nodes
    # variables for putting the nodes in a circle
    cluster_circle_const = 2*Math.PI/clusters.length;
    foci_width = @width/4
    foci_height = @height/4
    cluster_nodes = []

    # initialize clustered nodes
    for cluster, i in clusters
        cluster_nodes[i] = {
          radius: @config.cluster_radius_factor * Math.sqrt(cluster.nodes.length) + @config.cluster_radius_offset,
          text: cluster.label + " ("+cluster.nodes.length+")",
          x: circle_x(half_width, cluster_circle_const, i),
          y: circle_y(half_height, cluster_circle_const, i)
          cluster: true,
          nodes: cluster.nodes, # the array of node idx that this cluster contains
          focus: i+1 # +1 since 0 is center
          fill: @get_colour(i)
          stroke: d3.rgb(@get_colour(i)).darker(1).toString()
        }
        cluster_nodes[i].px = cluster_nodes[i].x
        cluster_nodes[i].py = cluster_nodes[i].y

        @nodes.push(cluster_nodes[i])

        @foci.push({
          x: circle_x(foci_width, cluster_circle_const, i),
          y: circle_y(foci_width, cluster_circle_const, i)
        })


    # update links to point to clusters
    for link in @links
      source_cluster = node_cluster_map[link.source.idx]
      target_cluster = node_cluster_map[link.target.idx]

      if source_cluster?
        link.source = cluster_nodes[source_cluster]

      if target_cluster?
        link.target = cluster_nodes[target_cluster]

    # remove self links
    @links = _.filter(@links, (link) -> link.source != link.target)

    @run()

  # TODO: implement me!
  display_aggregate: (attr) =>
    if attr and attr.trim().length != 0
      @set_display_mode(@display_modes.attribute, attr);

  # TODO: implement me!
  display_communities: () =>
    @set_display_mode(@display_modes.community)

  # TODO: implement me!
  display_raw: () =>
    @set_display_mode(@display_modes.raw)

  get_clusters: (nodes, links) =>
    # returns the list of clusters where each cluster has length > 1
    validate_clusters = (clusters) ->
      valid_clusters = []
      for cluster in clusters
        if cluster.nodes.length > 1 then valid_clusters.push(cluster)
      return valid_clusters

    # show raw data - no clusters
    if @display_mode.mode == @display_modes.raw
      return []

    # aggregate by attribute
    if @display_mode.mode == @display_modes.attribute
      attr = @display_mode.attribute # the attribute to aggregate on
      node_map = {}

      for node in nodes
        attr_val = node[attr]
        if node_map[attr_val] == undefined
          node_map[attr_val] = { label: attr+"="+attr_val, nodes: [] }

        # we only map the node idx (currently)
        node_map[attr_val].nodes.push(node.idx);

      # convert multi array format
      node_clusters = []
      for attribute, cluster of node_map
        node_clusters.push(cluster)

      return validate_clusters(node_clusters)

    if @display_mode.mode == @display_modes.community
      # TODO
      return []

    return []

  run: () =>
    @render()
    @start()
    @layout()

  render: () =>
    @visualization = d3.select('#vis').append('svg')
      .attr( 'width', @width)
      .attr('height', @height)
      .attr(    'id', 'svg_vis')

    $this = this

    d3.select(window).on('keydown', (d,i) -> $this.key_stroke())

    @node_drag = d3.behavior.drag()
      .on('drag',      (d,i) -> $this.dragmove(d,i,this))
      .on('dragstart', (d,i) -> $this.dragstart(d,i,this))
      .on('dragend',   (d,i) -> $this.dragend(d,i,this))

    @zoom = d3.behavior.zoom()
      .on('zoom', (d,i) -> $this.zooming(d,i))
      .scaleExtent([@zoom_min, @zoom_max])

    @visualization.call(@zoom)

    # build up the SVG
    @visualization.append("rect")
      .attr( 'width', '100%')
      .attr('height', '100%')
      .attr( 'style', 'opacity:.1') # rect is black by default??


    # draw foci as circles if configured
    if @config.show_foci
       @visualization.selectAll('circle.focus')
        .data(@foci)
        .enter().append("circle")
        .attr(           'r', 20)
        .attr(        'fill', "#222")
        .attr('stroke-width', 6)
        .attr(      'stroke', "#600")
        .attr(          'cx', (d, i) -> d.x)
        .attr(          'cy', (d, i) -> d.y)
        .attr(       'class', 'focus')
        .attr(          'id', (d, i) -> 'focus_'+i)
        .style('opacity', .2)


    # create links
    @lines = @visualization.selectAll('line.link')
      .data(@links)
      .enter().append('svg:line')
      .attr('stroke-width', (d) -> d.strokeWidth or $this.config.line_stroke_width)
      .attr(      'stroke', (d) -> d.stroke or $this.config.line_stroke)
      .attr(       'class', (d) -> if d.cluster_link then "link cluster_link" else "link")
      .attr(      'source', (d) -> d.source)
      .attr(      'target', (d) -> d.target)
      .attr(   'collapsed', (d) -> d.collapsed or 'false')
      .style(    'opacity', (d) -> d.opacity or $this.config.line_stroke_opacity)

    # create svg nodes for circles/labels
    @circles = @visualization.selectAll('g.node')
      .data(@nodes)
      .enter().append('g')
      .attr('class',   (d) -> if d.cluster then "node cluster" else "node")
      .attr('x', (d,i) -> d.x or $this.center.x)
      .attr('y', (d,i) -> d.y or $this.center.y)
      .on('mouseover', (d,i) -> $this.show_details(d,i,this))
      .on( 'mouseout', (d,i) -> $this.hide_details(d,i,this))
      .on(    'click', (d,i) -> $this.select_node(d,i,this))
      #.on(    'click', (d,i) -> $this.mark_node(d,i,this)) TODO mark
      .call(@node_drag)

    # create node circles
    @circles.append('circle')
      .attr(           'r', if @config.expand_circles_on_entry then 0 else (d) -> d.radius or $this.config.node_radius)
      .attr(        'fill', (d,i) => d.fill or $this.config.node_fill)
      .attr('stroke-width', (d,i) => d.strokeWidth or $this.config.node_stroke_width)
      .attr(      'stroke', (d,i) => d.stroke or $this.config.node_stroke)
      .attr(   'collapsed', 'false')
      .attr(           'cx', (d, i) => d.x or $this.center.x)
      .attr(           'cy', (d, i) => d.y or $this.center.y)
      .attr(           'id', (d, i) -> 'bubble_'+i)


    # create node labels
    @circles.append('text')
      .attr('text-anchor', 'middle')
      .attr(         'dy', '.3em')
      .attr(      'style', (d) => d.textStyle or $this.config.node_text_style)
      .attr(      'focus', (d) => d.focus or 0)
      .attr(  'collapsed', 'false')
      .text(       (d) =>  d.DOMNodeName or d.text or '')

    # circle expand transitions
    if @config.expand_circles_on_entry
      @circles.selectAll('circle').transition().duration(500)
        .attr('r', (d) -> d.radius or $this.config.node_radius)

  # run a force layout
  # Extended
  start: () =>

    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .charge(@charge)
      .gravity(@layout_gravity)
      .linkDistance((d) => (d.source.radius + d.target.radius)/2 + @link_distance)
      .linkStrength((d) => if d.cluster_link then 0.1 else 1)
      .size([@width, @height])


  # Replaces display_group_all
  # Supports multi-focus layout

  layout: () =>
    width = @width
    height = @height

    @force
      .on 'tick', (e) =>
        @circles.selectAll("circle")
          .each(@move_towards_focus(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
        @circles.selectAll("text").each(@move_towards_focus(e.alpha))
          .attr("x", (d) -> d.x)
          .attr("y", (d) -> d.y)
        @lines.attr("x1", (d) -> d.source.x)
          .attr("y1", (d) -> d.source.y)
          .attr("x2", (d) -> d.target.x)
          .attr("y2", (d) -> d.target.y)

        # allow for limiting ticks to prevent endless wandering
        @tick_count++
        if @tick_count > @config.tick_limit
          console.log "tick limit "+@config.tick_limit+" reached"
          @tick_count = 0
          # Force the layout to stop
          @force.stop()

    $("#loader").show();
    @force.start()

    # run through the first 100 ticks without drawing.
    if @config.static_load
      # move it along
      for i in [1..@config.static_load]
        @force.tick()
      @force.stop();

    $("#loader").hide();

  # Move node or text toward its focus
  move_towards_focus: (alpha) =>
    (d) =>
      d.x = d.x + (@foci[d.focus or 0].x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@foci[d.focus or 0].y - d.y) * (@damper + 0.02) * alpha

  # Fix node so it is free from force
  dragstart: (data, i, element) =>
    data.fixed = true

  dragmove: (data, i, element) =>
    data.px += d3.event.dx
    data.py += d3.event.dy
    data.x += d3.event.dx
    data.y += d3.event.dy

  dragend: (data, i, element) =>
    @force.resume()

  # Apply custom zoom function: as zoom occurs, show node names
  zooming: (data, i) =>
    if d3.event?
      # maintain stroke widths to make zoom more useful.
      @circles.attr("transform", "translate(" + d3.event.translate + ") " +
        "scale(" + d3.event.scale + ")")
        .selectAll("circle")
          .attr("stroke-width", if d3.event.scale > 1 then @config.node_stroke_width/d3.event.scale else @config.node_stroke_width)
          .attr("r", (d) -> if d3.event.scale > 1 then d.radius/d3.event.scale else d.radius)

      @lines.attr("transform", "translate(" + d3.event.translate + ") " +
        "scale(" + d3.event.scale + ")")
        .attr("stroke-width", if d3.event.scale > 1 then @config.line_stroke_width/d3.event.scale else @config.line_stroke_width)


  # Node hover tool tip
  show_details: (data, i, element) =>
    # Emphasis hovered node
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", "black")

    hidden  = ['children', '_children', 'x', 'y', 'px', 'cx', 'cy', 'DOMNodeName',
                'y', 'py', 'index', 'fixed', 'fill', 'stroke', 'strokeWidth','radius',
                'nodes', 'idx']

    content = "<table>"
    for key, value of data
      if hidden.indexOf(key) == -1
        content += "<tr><td><span class=\"name\">#{key}</span></td>" +
          "<td><span class=\"value\"> #{value}</span></td></tr>"

    content += "</table>"
    @tooltip.showTooltip(content,d3.event)

  # Remove node hover tool tip
  hide_details: (data, i, element) =>
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", (d) => "#d84b2a")
    @tooltip.hideTooltip()

  # mouse click listener that marks a node
  mark_node: (data, i, element) =>
    console.log(data, i, element);
    $circle = $(element).find("circle");
    if $circle.attr("marked")
      $circle.removeAttr("marked").attr("fill", @config.node_fill)
    else
      $circle.attr("marked", true).attr("fill", "red").attr("idx", data.idx)

    @force.stop()

  # for building cluster array
  output_marked_nodes: () =>
    console.log $.makeArray($("circle[marked]").map(() -> parseInt(this.attributes.idx.value))).join()

  # Make the selected node 'focused'
  # Apply style and show meta data
  select_node: (data, i, element) =>
    # create that to preserve this within d3 select each call
    that = this

    # make the damn thing stop moving when something is clicked.
    @force.stop()

    # revert previously selected
    this.clear_selection()

    # handle clusters differently
    if data.cluster
      this.select_cluster(data)
      return

    # Emphasize selected node
    element.ownerSVGElement.appendChild(element) # move element to top
    @focused_node = d3.select(element)
    @focused_node_data = data
    @focused_node.select("circle")
      .attr("r", (data.radius or @config.node_radius) + @config.focused_radius_offset)
      .attr("fill", @config.focused_fill)
      .attr("stroke", @config.focused_stroke)

    # Show details in properties panel
    content = "<table class=\"attr-table\">" # fix this
    hidden  = ['children', '_children', 'x', 'y', 'px', 'cx', 'cy', 'DOMNodeName',
                'y', 'py', 'index', 'fixed', 'fill', 'stroke', 'strokeWidth','radius',
                'nodes','name','cluster', 'text', 'idx']

    $('#aggr_menu').children().remove();

    $('#meta_title').html('Person')
    $('#meta_detail').html(data.name)
    $('#meta_schema').show()

    for key, value of data
      if hidden.indexOf(key) == -1
        content += "<tr><td><!--<input type=\"checkbox\" id=\"check_#{key}\" />&nbsp;--><span class=\"name\">#{key}</span></td>" +
          "<td><span class=\"pinnable\"> #{value}</span></td></tr>"

        $('#aggr_menu').append("<li><a tabindex=\"-1\">#{key}</a></li>");

    content += "</table>"

    $('#meta_attr').html(content)
    $('#prop_meta').fadeIn();

    $('#meta_schema').unbind('click')
    #$('#meta_schema').click(() => @show_schema(data))

    $('#aggr_menu a').click(() ->
      $('#aggr_menu a').removeAttr('data-selected').css('font-weight','normal')
      $(this).css('font-weight', 'bold')
      $(this).attr('data-selected', true)
      that.display_aggregate($(this).html())
    )

    # Default attribute to aggregate on is
    # the first one...
    $('#aggr_menu > li:first-child a')
    .css('font-weight', 'bold')
    .attr('data-selected', true)

  # assumes data represents a cluster (i.e. data.cluster = true)
  select_cluster: (data) =>
    @history_snapshot(@display_mode, @current_filter_node_list)
    if @display_mode.mode == @display_modes.attribute
      this.set_display_mode(@display_modes.raw, null, false) # do not redraw

    # show the cluster detail
    $("#cluster_detail").html(data.text)

    content = "<table class=\"attr-table\">"
    hidden  = ['children', '_children', 'x', 'y', 'px', 'cx', 'cy', 'DOMNodeName',
              'y', 'py', 'index', 'fixed', 'fill', 'stroke', 'strokeWidth','radius',
              'nodes','name','cluster', 'text', 'idx']
    for key, value of data
      if hidden.indexOf(key) == -1
        content += "<tr><td><!--<input type=\"checkbox\" id=\"check_#{key}\" />&nbsp;--><span class=\"name\">#{key}</span></td>" +
          "<td><span class=\"pinnable\"> #{value}</span></td></tr>"
    content += "</table>"
    $("#cluster_attr").html(content)
    $("#prop_cluster").fadeIn();

    this.display(data.nodes)

  #show_schema: (data) =>
  #  alert(data.name + '!')

  # Remove node from 'focus'
  clear_selection: () =>
    if @focused_node?
      @focused_node.select("circle")
        .attr("r", @focused_node_data.radius or @config.node_radius)
        .attr("fill", @focused_node_data.fill or @config.node_fill)
        .attr("stroke", @focused_node_data.stroke or @config.node_stroke)

    @focused_node = null
    $("#prop_meta").hide()


  # Extra functionality through key shortcuts
  key_stroke: () =>
    if d3.event?
      # Aggregate node (not fully implemented)
      switch d3.event.keyCode
        when 65
          node_name = @focused_node_data.DOMNodeName
          @circles.each( (d,i) ->
            if d.DOMNodeName == node_name
              console.log node_name
          )
        when 67
          # Show or hide children (key: 'C')
          if @focused_node_data?
            if @focused_node_data.children.length isnt 0
              @hide_children null
            else if @focused_node_data._children.length isnt 0
              @show_children null
        when 32
          # toggle between playing/pausing the force layout (key: ' ')
          if @force.alpha() == 0
            @force.start()
          else
            @force.stop()
        else
          console.log d3.event.keyCode

  # Recurse through children and hide those nodes from the vis
  hide_children: (children) =>
    unless children?
      @focused_node.select("circle").attr("fill", "#3b5998")
      @focused_node.select("circle").attr("stroke", "#263d6c")
      children = @focused_node_data.children
      # Copy flattened children to buffer
      @focused_node_data["_children"] = children
      @focused_node_data["children"] = []
    for node in children
      # Depth first, recurse through children
      @hide_children node.children

      # Remove child lines and nodes from vis
      @circles.each( (d,i) ->
        if i == node.DOMNodeID
          d3.select(@).select("circle")
            .attr("style", "display:none")
            .attr("collapsed", "true")
          d3.select(@).select("text")
            .attr("style", "display:none")
            .attr("collapsed", "true"))
      @lines.each( (d, i) ->
        if d.target.DOMNodeID == node.DOMNodeID
          d3.select(@)
            .attr("style", "display:none")
            .attr("collapsed", "true"))

  # Recurse through children and show those nodes in the vis
  show_children: (children) =>
    parent = false
    unless children?
      parent = true
      @focused_node.select("circle").attr("fill", "#8b9dc3")
      @focused_node.select("circle").attr("stroke", "#3b5998")
      children = @focused_node_data._children
      # Copy expanded children back into children slot
      @focused_node_data["children"] = children
      @focused_node_data["_children"] = []
    for node in children
      # Depth first, recurse through children
      @show_children node.children

      that = this
      # Show child node and links to parent
      # Apply style according to zoom and node selection
      @circles.each( (d,i) ->
        if i == node.DOMNodeID
          d3.select(@).select("circle")
            .attr("style", "")
            .attr("collapsed", "false")
          # Apply text opacity depending on zoom
          text = d3.select(@).select("text")
          text.attr("collapsed", "false")
          if that.zoom_current_tier > @zoom_max * @zoom_show_labels
            text.attr("style", "")
          else if that.zoom_current_tier > @zoom_max * @zoom_hint_labels
            text.attr("style", "opacity:.5")
          else
            text.attr("style", "opacity:0"))
      @lines.each( (d, i) ->
        if d.target.DOMNodeID == node.DOMNodeID
          if parent
            d3.select(@)
              .attr("collapsed", "false")
              .attr("style", "opacity:.7")
          else
            d3.select(@)
              .attr("collapsed", "false")
              .attr("style", "opacity:.2"))


root = exports ? this

# Run the visualization on an XML file
$ ->
  chart = null

  render_vis = (xml) ->
    chart = new XMLSchema xml
    #chart.start_ex()
    root.display_all()
    $("#debug_btn1").click(() => chart.display())
    $("#reset_btn").click(() => chart.history_reset())

    # Raw data
    $('#viz1_btn').click(()   => chart.display_raw())
    # Communities
    $('#viz2_btn').click(()   => chart.display_communities())
    # Aggregate
    $('#viz3_btn').click(() =>
      chart.display_aggregate($('#aggr_menu a[data-selected="true"]').html())
    )
    # Back button
    window.onpopstate = (e)   => chart.history_popstate(e)

  root.display_all = () =>
    chart.display()

  d3.xml "data/FB-RAW-3.xml", render_vis

