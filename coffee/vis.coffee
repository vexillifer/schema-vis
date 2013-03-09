# Explores and visualizes XML data, schema agnostic
# Melsa Smith, Aug 2012

counter = 0

class XMLSchema
  constructor: (data) ->
    
    # default vis style settings
    @config = {
      node_fill: '#8b9dc3',
      node_stroke: '#3b5998',
      node_stroke_width: 2,
      node_radius: 30,
      node_text_style: '',
      line_stroke_width: 5,
      line_stroke: 'black',
      line_stroke_opacity: .2
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
    @link_distance = 80

    # network data
    @people = []
    @index  = {}

    @circles = null
    @visualization = null

    @tooltip = CustomTooltip("node_tooltip", 240)
    @center = {x: @width / 2, y: @height / 2}
    @layout_gravity = -.2
    @damper = 0.1
    @force = null
    @node_drag = null
    @zoom = null

    @focused_node = null
    @focused_node_data = null

    if @data.firstChild.nodeName == 'network'
      @explore_network(@data)
      @viz_default()
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

  viz_reset: () =>
    @nodes.length = 0
    @foci.length  = 0
    @links.length = 0
    @link_distance = 80

  viz_default: () =>
    @viz_reset()

    # Show a summary of a person
    posts = {}
    photos = {}
    statuses = {}

    person = {
      'name': 'String',
      'sex': 'ENUM{male,female}',
      'locale': 'ENUM{en_US,en_GB}',
      'uid': 'Integer',
      'DOMNodeName': 'person',
      'children': [],
      '_children': []
    }

    photos = {
      'DOMNodeName': 'photos',
      'children': [],
      '_children': []
    }

    posts = {
      'DOMNodeName': 'posts',
      'children': [],
      '_children': []
    }

    statuses = {
      'DOMNodeName': 'statuses',
      'children': [],
      '_children': []
    }

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

    @visualize_ex()
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
  visualize_ex: () =>
    @visualization = d3.select('#vis').append('svg')
      .attr( 'width', @width)
      .attr('height', @height)
      .attr(    'id', 'svg_vis')

    $this = this

    d3.select(window).on('keydown', (d,i) -> $this.key_stroke_ex())

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
      .data(@nodes, (d) -> d.DomParentID)
      .enter().append('g')      
      .attr('class',   'node')
      .on('mouseover', (d,i) -> $this.show_details(d,i,this))
      .on( 'mouseout', (d,i) -> $this.hide_details(d,i,this))
      .on(    'click', (d,i) -> $this.select_node(d,i,this))
      .call(@node_drag)

    # create node circles 
    @circles.append('circle')
      .attr('r', 0)
      .attr(        'fill', (d,i) => d.fill or $this.config.node_fill)
      .attr('stroke-width', (d,i) => d.strokeWidth or $this.config.node_stroke_width)
      .attr(      'stroke', (d,i) => d.stroke or $this.config.node_stroke)
      .attr(   'collapsed', 'false')
      .attr(          'id', (d) -> 'bubble_#{d.DOMNodeID}')

    # create node labels
    @circles.append('text')
      .attr('text-anchor', 'middle')
      .attr(         'dy', '.3em')
      .attr(      'style', (d) => d.textStyle or $this.config.node_text_style)
      .attr(  'collapsed', 'false')
      .text(       (d) =>  d.DOMNodeName or d.text or '')

    # circle expand transitions
    @circles.selectAll('circle').transition().duration(2000)
      .attr('r', (d) -> d.radius or $this.config.node_radius)

  # run a force layout
  # Extended
  start_ex: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .linkDistance(@link_distance)
      .size([@width, @height])


  # respond to zoom level
  # Extended
  zooming_ex: () =>
    return


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
      @circles.attr("transform", "scale(" + d3.event.scale + ") " +
        "translate(" + d3.event.translate + ")")
      @lines.attr("transform", "scale(" + d3.event.scale + ") " +
        "translate(" + d3.event.translate + ")")

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

  # Uses D3.js gravity layout
  charge: (d) -> 
    -500
    # -Math.pow(@radius, 2.0) / 8

  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .linkDistance(80)
      .size([@width, @height])

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

  # Node hover tool tip
  show_details: (data, i, element) =>
    # Emphasis hovered node
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", "black")

    content = "<table>"
    for key, value of data
      unless key == "children" || key == "_children" || key == "x" || 
      key == "px" || key == "y" || key == "py" || key == "index"
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
    for key, value of data
      unless key == "children" || key == "_children" || key == "x" || key == "px" ||
       key == "y" || key == "py" || key == "index" || key == "fixed"
        content += "<tr><td><img src=\"/img/pin-icon.png\" class=\"pin\" width=\"16\" \" />&nbsp;<span class=\"name\">#{key}</span></td>" + 
          "<td><span class=\"pinnable\"> #{value}</span></td></tr>"

    content += "</table>"

    d3.selectAll("#prop_panel").html(content)
    d3.selectAll(".pin").on("click", (d,i) -> that.pin(d,i,this))

  # Remove node from 'focus'
  clear_selection: (data, i, element) =>
    @lines.attr("style", "opacity:.2")
    @focused_node.attr("r", 15) if @focused_node?
    @focused_node = null
    d3.selectAll("#prop_panel").html("")
  

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
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()

  d3.xml "data/FB-RAW-3.xml", render_vis

