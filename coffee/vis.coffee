# Explores and visualizes XML data, schema agnostic
# Melsa Smith, Aug 2012

# TODO: Multiple foci tests, clustering tests.

counter = 0

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
      # performance otions
      static_load: 0,
      expand_circles_on_entry: false
    }

    @width = window.innerWidth
    @height = window.innerHeight
    @data = data

    @zoom_min = .5
    @zoom_max = 2
    @zoom_show_labels = 7/8
    @zoom_hint_labels = 3/4
    zoom_current_tier = 1

    # these parameters completely
    # specify a visualization
    @nodes  = []
    @links  = []
    @foci   = []
    @charge = -500
    @link_distance = 80
    @display = null

    # network data
    @people = []
    @connections = []
    @index  = {}

    @circles = null
    @visualization = null

    @tooltip = CustomTooltip("node_tooltip", 240)
    @center = {x: @width / 2, y: @height / 2}
    @layout_gravity = 0.1
    @damper = 0.1
    @force = null
    @node_drag = null
    @zoom = null

    @focused_node = null
    @focused_node_data = null

    if @data.firstChild.nodeName == 'network'
      @explore_network(@data)
      #@viz_default()
    else
      #@explore_data @data, {}
      #@visualize()
      console.error 'Data is not a social network.'

  # Compute all nodes and links in network
  # 1) Create a node for each profile
  # 2) Create a link for each connection
  explore_network: (network) =>
    node = {}
    attrs = ['uid','name','sex','locale']

    people = network.firstChild.querySelectorAll('person')
    connections = network.firstChild.querySelectorAll('connection')

    for person in people
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
      @index[copy.name] = copy
      @people.push(copy)

    for connection in connections
      uid1 = connection.querySelector('uid1').firstChild.nodeValue
      uid2 = connection.querySelector('uid2').firstChild.nodeValue
      @connections.push([uid1, uid2])


  reset: () =>
    @nodes.length = 0
    @foci.length  = 0
    @links.length = 0
    @display = null
    $('#svg_vis').remove()

  display_default: (zoom) =>
    @reset()

    # variables for putting the nodes in a circle
    circleConst = 2*Math.PI/@people.length;
    halfWidth = @width/2;
    halfHeight = @height/2;

    for person, i in @people
      person.radius = 5
      person.text = ''
      person.DOMNodeName = ''
      person.x = @center.x+(halfWidth)*Math.cos(circleConst*i);
      person.y = @center.y+(halfHeight)*Math.sin(circleConst*i);
      person.px = person.x
      person.py = person.y
      @nodes.push(person)

    for connection in @connections
      link = {
        source: @index[connection[0]]
        target: @index[connection[1]]
      }
      @links.push(link)

    @foci.push(@center)
    # Show a summary of a person
    ###
    posts = {}
    photos = {}
    statuses = {}

    person = {
      'name': 'String',
      'sex': 'ENUM{male,female}',
      'locale': 'ENUM{en_US,en_GB}',
      'uid': 'Integer',
      'DOMNodeName': 'person',
      'fill': '#FFC900',
      'stroke': '#BFA130',
      'radius': 40,
      'children': [],
      '_children': [],
      'cx': @center.x,
      'cy': @center.y
    }

    photos = {
      'DOMNodeName': 'photos',
      'focus': 0,
      'radius': 30,
      'children': [],
      '_children': []
    }

    posts = {
      'DOMNodeName': 'posts',
      'focus': 0,
      'radius': 25,
      'children': [],
      '_children': []
    }

    statuses = {
      'DOMNodeName': 'statuses',
      'focus': 0,
      'radius': 30,
      'children': [],
      '_children': []
    }

    @link_distance = 80

    person.children.push(photos)
    person.children.push(posts)
    person.children.push(statuses)

    @nodes.push(person)
    @nodes.push(photos)
    @nodes.push(posts)
    @nodes.push(statuses)

    @links.push({'source': person,'target': photos})
    @links.push({'source': person,'target': posts})
    @links.push({'source': person,'target': statuses})

    # default focus is center
    @foci.push(@center)
    #@foci.push({x: @center.x - 200, y: @center.y})
    #@foci.push({x: @center.x + 200, y: @center.y})
    #@foci.push({x: @center.x, y: @center.y + 200})
    ###

    @run()

  display_refs: (zoom) =>
    @reset()

    max = 50
    cur = 0

    for person in @people
      if cur >= max
        break
      @nodes.push(person)
      cur++

    # create some links
    for i in [0..@nodes.length - 1]
      dex = Math.floor(Math.random()*@nodes.length)
      if dex != i
        link = {
          'source': @nodes[i],
          'target': @nodes[dex]
        }
        #console.log(@nodes[i].name + ' -> ' + @nodes[dex].name)
        @links.push($.extend({}, link))

    @foci.push(@center)

    @run()

  display_struct: (zoom) =>
    # this is intended to group by other labelled edges
    # we really only know about friendships, but
    # other edges could exist (family, friends, classmates)

  display_attr: (zoom) =>
    # cluster on selected attributes
    @reset()

    #max = 50
    #cur = 0
    c0 = []
    c1 = []

    find_person = (name, a) =>
      for p in a
        if p.name == name
          return true
      return false


    for i in [0..@people.length - 1]
      person = @people[i]
      person.fill = if i % 2 == 0  then 'red' else @config.node_fill
      person.stroke = if i % 2 == 0 then 'darkred' else @config.node_stroke
      person.focus = if i % 2 == 0 then 1 else 0
      person.text = ''
      person.DOMNodeName = ''
      person.radius = @config.node_radius
      if i % 2 == 0
        c0.push(person)
      else
        c1.push(person)
      @nodes.push(person)

    # generate some links in each cloud
    ###
    for i in [0..c0.length - 1]
      dex = Math.floor(Math.random()*c0.length)
      link = {
        'source': c0[i],
        'target': c0[dex]
      }
      @links.push($.extend({}, link))

    for i in [0..c1.length - 1]
      dex = Math.floor(Math.random()*c1.length)
      link = {
        'source': c1[i],
        'target': c1[dex]
      }
      @links.push($.extend({}, link))
    ###

    for connection in @connections
      if (find_person(connection[0], c0) and find_person(connection[1], c0)) or (find_person(connection[0], c1) and find_person(connection[1], c1))
        link = {
          source: @index[connection[0]]
          target: @index[connection[1]]
        }
        @links.push(link)

    ###
    @nodes.push({
      'radius': 100,
      'text': 'locale: en_US',
      'focus': 1,
      'fill': 'red',
      'stroke': 'darkred'
    })

    @nodes.push({
      'radius': 80,
      'text': 'locale: en_GB',
      'focus': 0
    })


    @links.push({
      'target': @nodes[0],
      'source': @nodes[1]
    })


    @link_distance = 300
    ###

    @foci.push({x: @center.x - window.innerWidth/8, y: @center.y})
    @foci.push({x: @center.x + window.innerWidth/8, y: @center.y})

    @run()

  display_quad: () =>
    @reset()

    colors = ['red','green','pink','blue']

    for i in [0..@people.length - 1]
      quad = Math.floor(Math.random()*4)
      person = @people[i]
      person.focus = quad
      person.stroke = 'black'
      person.fill = colors[quad]
      person.text = ''
      person.DOMNodeName = ''
      person.radius = 10
      @nodes.push(person)

    @foci.push({x: @center.x - window.innerWidth/8, y: @center.y - window.innerWidth/8})
    @foci.push({x: @center.x - window.innerWidth/8, y: @center.y + window.innerWidth/8})
    @foci.push({x: @center.x + window.innerWidth/8, y: @center.y - window.innerWidth/8})
    @foci.push({x: @center.x + window.innerWidth/8, y: @center.y + window.innerWidth/8})

    @run()

  run: () =>
    @render()
    @start()
    @layout()
  # Builds schema structure
  # Method: Creates a node for parent element and recurse through
  # children and siblings. Uses prevID to create links from child -> parent
  ###
  explore_data: (parent, prevNode) =>
    node = {}
    link = {}

    # Arbitrary limit to visualization size, replace with summarization
    unless counter > 75

      # if parent.nodeType == 3
      #   if parent.data.length not 0
      #     console.log parent.data

      # Set node's identifying features, for the visualization's context
      if parent.nodeType == 1
        node["DOMNodeID"] = counter++
        node["DOMNodeName"] = parent.nodeName
        node["children"] = []
        node["_children"] = []

      # Add element's attributes added as node meta data
      attributes = parent.attributes
      if attributes? && attributes.length != 0
        for index in [0..attributes.length-1]
          attr = attributes.item(index)
          node["#{attr.nodeName}"] = attr.nodeValue
      @nodes.push node unless jQuery.isEmptyObject(node)

      # Add PC links
      if not jQuery.isEmptyObject(prevNode) && not jQuery.isEmptyObject(node)
        link["source"] = prevNode
        link["target"] = node
        prevNode["children"].push node
      @links.push link unless jQuery.isEmptyObject(link)

      # Add first child node
      firstChild = parent.firstChild
      @explore_data firstChild, node if firstChild?

      # Add next sibling
      sibling = parent.nextSibling
      @explore_data sibling, prevNode if sibling?

  # Create the visual elements for the tree components
  # Uses D3.js for visualization
  # Extended to support per-node properties:
  # stroke, strokeWidth, fill, text, textStyle, radius
  ###
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

    # create links
    @lines = @visualization.selectAll('line.link')
      .data(@links)
      .enter().append('svg:line')
      .attr('stroke-width', (d) -> d.strokeWidth or $this.config.line_stroke_width)
      .attr(      'stroke', (d) -> d.stroke or $this.config.line_stroke)
      .attr(       'class', 'link')
      .attr(      'source', (d) -> d.source)
      .attr(      'target', (d) -> d.target)
      .attr(   'collapsed', (d) -> d.collapsed or 'false')
      .style(    'opacity', (d) -> d.opacity or $this.config.line_stroke_opacity)

    # create svg nodes for circles/labels
    @circles = @visualization.selectAll('g.node')
      .data(@nodes)
      .enter().append('g')
      .attr('class',   'node')
      .attr('x', (d,i) -> $this.center.x)
      .attr('y', (d,i) -> $this.center.y)
      .on('mouseover', (d,i) -> $this.show_details(d,i,this))
      .on( 'mouseout', (d,i) -> $this.hide_details(d,i,this))
      .on(    'click', (d,i) -> $this.select_node(d,i,this))
      .call(@node_drag)

    # create node circles
    @circles.append('circle')
      .attr(           'r', if @config.expand_circles_on_entry then 0 else (d) -> d.radius or $this.config.node_radius)
      .attr(        'fill', (d,i) => d.fill or $this.config.node_fill)
      .attr('stroke-width', (d,i) => d.strokeWidth or $this.config.node_stroke_width)
      .attr(      'stroke', (d,i) => d.stroke or $this.config.node_stroke)
      .attr(   'collapsed', 'false')
      .attr(           'x', (d, i) => d.x or $this.center.x)
      .attr(           'y', (d, i) => d.x or $this.center.y)
      .attr(          'id', (d) -> 'bubble_#{d.DOMNodeID}')


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
      .linkDistance(@link_distance)
      .size([@width, @height])


  # Replaces display_group_all
  # Supports multi-focus layout

  layout: () =>
    width = @width
    height = @height
    @force
      .on 'tick', (e) =>
        @circles.selectAll("circle").each(@move_towards_focus(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
        @circles.selectAll("text").each(@move_towards_focus(e.alpha))
          .attr("x", (d) -> d.x)
          .attr("y", (d) -> d.y)
        @lines.attr("x1", (d) -> d.source.x)
          .attr("y1", (d) -> d.source.y)
          .attr("x2", (d) -> d.target.x)
          .attr("y2", (d) -> d.target.y)


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

  # Create the visual elements for the tree components
  # Uses D3.js for visualization
  ###
  visualize: () =>
    @visualization = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    that = this

    d3.select(window).on("keydown", (d,i) -> that.key_stroke())

    # Define drag and zoom behaviours
    @node_drag = d3.behavior.drag()
      .on("dragstart", (d,i) -> that.dragstart(d,i,this))
      .on("drag", (d,i) -> that.dragmove(d,i,this))
      .on("dragend", (d,i) -> that.dragend(d,i,this))

    @zoom = d3.behavior.zoom()
      .on("zoom", (d,i) -> that.zooming(d,i))
      .scaleExtent([@zoom_min, @zoom_max])
    @visualization.call(@zoom)

    @visualization.append("rect")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr("style", "opacity:.1")

    # Add lines as an under layer
    @lines = @visualization.selectAll("line.link")
      .data(@links)
      .enter().append("svg:line")
      .attr("stroke-width", (d) -> 5)
      .attr("stroke", "black")
      .attr("class", "link")
      .attr("source", (d) -> d.source)
      .attr("target", (d) -> d.target)
      .attr("collapsed", "false")
      .style(opacity: .2)

    # Create a node element to append the svg circle and label
    @circles = @visualization.selectAll("g.node")
      .data(@nodes, (d) -> d.DomParentID)
      .enter().append("g")
      .attr("class", "node")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))
      .on("click", (d,i) -> that.select_node(d,i,this))
      .call(@node_drag)

    @circles.append("circle")
      .attr("r", 0)
      .attr("fill", (d) => "#8b9dc3")
      .attr("stroke-width", 2)
      .attr("stroke", (d) => "#3b5998")
      .attr("collapsed", "false")
      .attr("id", (d) -> "bubble_#{d.DOMNodeID}")

    @circles.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", ".3em")
      .attr("style", "")
      .attr("collapsed", "false")
      .text((d) => d.DOMNodeName)

    @circles.selectAll("circle").transition().duration(2000)
      .attr("r", (d) -> 30)
  ###

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
      @circles.attr("transform", "scale(" + d3.event.scale + ") " +
        "translate(" + d3.event.translate + ")")
        .selectAll("circle")
          .attr("stroke-width", if d3.event.scale > 1 then @config.node_stroke_width/d3.event.scale else @config.node_stroke_width)
          .attr("r", (d) -> if d3.event.scale > 1 then d.radius/d3.event.scale else d.radius)

      @lines.attr("transform", "scale(" + d3.event.scale + ") " +
        "translate(" + d3.event.translate + ")")
        .attr("stroke-width", if d3.event.scale > 1 then @config.line_stroke_width/d3.event.scale else @config.line_stroke_width)

      # call the current visualization engine with the new zoom level
      #@display(d3.event.scale)

      ###
      zoom_current_tier = d3.event.scale
      # if zoomed in, show the node labels
      if d3.event.scale > @zoom_max * @zoom_show_labels
        d3.selectAll("text").each((d, i) ->
          if d3.select(@).attr("collapsed") == "false"
            d3.select(@).attr("style", ""))
      else if d3.event.scale > @zoom_max * @zoom_hint_labels
        d3.selectAll("text").each((d, i) ->
          d3.select(@).attr("collapsed")
          if d3.select(@).attr("collapsed") == "false"
            d3.select(@).attr("style", "opacity:.5"))
      else
        d3.selectAll("text").attr("style", "display:none")
      ###

  # Uses D3.js gravity layout
  #charge: (d) ->
  #  -500
    # -Math.pow(@radius, 2.0) / 8

  ###
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .linkDistance(80)
      .size([@width, @height])
  ###
  ###
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(@charge)
      .friction(.9)
      .on "tick", (e) =>
        @circles.selectAll("circle").each(@move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
        @circles.selectAll("text").each(@move_towards_center(e.alpha))
          .attr("x", (d) -> d.x)
          .attr("y", (d) -> d.y)
        @lines.attr("x1", (d) -> d.source.x)
          .attr("y1", (d) -> d.source.y)
          .attr("x2", (d) -> d.target.x)
          .attr("y2", (d) -> d.target.y)

    @force.start()
  ###
  ###
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  pin: (data, i, element) =>
    key = element.parentNode.previousSibling.innerHTML
    @label_node(@focused_node, @focused_node_data[key])

  label_node: (node, value) =>
    # node.append("text")
    #   .text(value)
    #   .attr("dx", 12)
    #   .attr("dy", ".35em")
    # console.log node
  ###
  # Node hover tool tip
  show_details: (data, i, element) =>
    # Emphasis hovered node
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", "black")

    hidden  = ['children', '_children', 'x', 'y', 'px', 'cx', 'cy', 'DOMNodeName',
                'y', 'py', 'index', 'fixed', 'fill', 'stroke', 'strokeWidth','radius']

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

  # Make the selected node 'focused'
  # Apply style and show meta data
  select_node: (data, i, element) =>
    # create that to preserve this within d3 select each call
    that = this

    # Emphasis adjacent lines
    if @focused_node_data?
      focused_node_id = @focused_node_data.DOMNodeID
    else focused_node_id = null
    @lines.each( (d, i) ->
      line = d3.select(@)
      if focused_node_id?
        if d.source.DOMNodeID == focused_node_id || d.target.DOMNodeID == focused_node_id
          if line.attr("collapsed") == "false"
            line.attr("style", "opacity:.2")
      if d.source.DOMNodeID == data.DOMNodeID || d.target.DOMNodeID == data.DOMNodeID
        if line.attr("collapsed") == "false"
          line.attr("style", "opacity:.7"))

    # Emphasis selected node
    element.ownerSVGElement.appendChild(element)
    @focused_node.attr("r", 15) if @focused_node?
    d3.select(element).attr("r", 25)
    @focused_node = d3.select(element)
    @focused_node_data = data

    # Show details in properties panel
    content = "<table class=\"attr-table\">" # fix this
    hidden  = ['children', '_children', 'x', 'y', 'px', 'cx', 'cy', 'DOMNodeName',
                'y', 'py', 'index', 'fixed', 'fill', 'stroke', 'strokeWidth','radius']

    for key, value of data
      if hidden.indexOf(key) == -1
        content += "<tr><td><input type=\"checkbox\" id=\"check_#{key}\" />&nbsp;<span class=\"name\">#{key}</span></td>" +
          "<td><span class=\"pinnable\"> #{value}</span></td></tr>"

    content += "</table>"

    d3.selectAll("#prop_meta").html(content)
    $('#prop_panel').fadeIn()
    $('#prop_meta input').on('click', () ->
      checked = $(this).prop('checked')
      if checked
        $(this).parent().parent().addClass('selected')
      else
        $(this).parent().parent().removeClass('selected')
    )
    #d3.selectAll(".pin").on("click", (d,i) -> that.pin(d,i,this))

  # Remove node from 'focus'
  clear_selection: (data, i, element) =>
    @lines.attr("style", "opacity:.2")
    @focused_node.attr("r", 15) if @focused_node?
    @focused_node = null
    d3.selectAll("#prop_meta").html("")
    $('#prop_panel').fadeOut()


  # Extra functionality through key shortcuts
  key_stroke: () =>
    if d3.event?
      # Aggregate node (not fully implemented)
      if (d3.event.keyCode == 65)
        node_name = @focused_node_data.DOMNodeName
        @circles.each( (d,i) ->
          if d.DOMNodeName == node_name
            console.log node_name
        )
      if (d3.event.keyCode == 67)
        # Show or hide children (key: 'C')
        if @focused_node_data?
          if @focused_node_data.children.length isnt 0
            @hide_children null
          else if @focused_node_data._children.length isnt 0
            @show_children null

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
    $('#viz1_btn').click(() => chart.display_refs())
    $('#viz2_btn').click(() => chart.display_quad())
    $('#viz3_btn').click(() => chart.display_attr())

  root.display_all = () =>
    chart.display_default()

  d3.xml "data/FB-RAW-3.xml", render_vis

