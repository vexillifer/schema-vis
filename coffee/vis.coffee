# Explores and visualizes XML data, schema agnostic
# Melsa Smith, Aug 2012

counter = 0

class XMLSchema
  constructor: (data) ->
    @width = 800
    @height = 700
    @data = data

    @zoom_min = .5
    @zoom_max = 2
    @zoom_show_labels = 7/8
    @zoom_hint_labels = 3/4
    zoom_current_tier = 1

    @nodes = []
    @links = []
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

    @explore_data @data, {}
    @visualize()


  # Create node for parent and explore children and siblings
  # Use prevID to create links from child -> parent
  explore_data: (parent, prevNode) =>
    # Add current node
    node = {}
    link = {}

    unless counter > 75

      # if parent.nodeType == 3
      #   if parent.data.length not 0
      #     console.log parent.data

      if parent.nodeType == 1
        node["DOMNodeID"] = counter++
        node["DOMNodeName"] = parent.nodeName
        node["children"] = []
        node["_children"] = []

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

  visualize: () =>
    @visualization = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    # d3.selectAll("header")
    #   .on("click", (d,i) -> that.clear_selection(d,i,this))

    d3.select(window).on("keydown", (d,i) -> that.key_stroke())

    that = this

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

    # Add lines as under layer
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
      .attr("fill", (d) => "#d84b2a")
      .attr("stroke-width", 2)
      .attr("stroke", (d) => "#d84b2a")
      .attr("collapsed", "false")
      .attr("id", (d) -> "bubble_#{d.DOMNodeID}")

    @circles.append("text")
      .attr("text-anchor", "middle")
      .attr("dy", ".3em")
      .attr("style", "display:none")
      .attr("collapsed", "false")
      .text((d) => d.DOMNodeName)

    @circles.selectAll("circle").transition().duration(2000)
      .attr("r", (d) -> 15)


  charge: (d) -> 
    -500
    # -Math.pow(@radius, 2.0) / 8

  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .size([@width, @height])

  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(@charge)
      .friction(.9)
      .on "tick", (e) =>
        @circles.selectAll("circle").each(@move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
          # .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")
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

  show_details: (data, i, element) =>
    # Emphasis hovered node
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", "black")

    content = ""
    for key, value of data
      unless key == "children" || key == "_children" || key == "x" || key == "px" || key == "y" || key == "py" || key == "index"
        content += "<span class=\"name\">#{key}</span>" + 
          "<span class=\"value\"> #{value}</span><br/>"
    @tooltip.showTooltip(content,d3.event)

  hide_details: (data, i, element) =>
    if d3.select(element).attr("collapsed") == "false"
      d3.select(element).select("circle").attr("stroke", (d) => "#d84b2a")
    @tooltip.hideTooltip()

  clear_selection: (data, i, element) =>
    @lines.attr("style", "opacity:.2")
    @focused_node.attr("r", 15) if @focused_node?
    @focused_node = null
    d3.selectAll("#prop_panel").html("")

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
    content = "<br/><br/><br/><br/><br/><br/>" # fix this
    for key, value of data
      unless key == "children" || key == "_children" || key == "x" || key == "px" || key == "y" || key == "py" || key == "index" || key == "fixed"
        content += "<span class=\"name\">#{key}</span>" + 
          "<span class=\"pinnable\"> #{value}" + 
            "<img src=\"..\\img\\pin-icon.png\" class=\"pin\" " +
              "width=\"15\" alt=\"pin\"/></span><br/>"

    d3.selectAll("#prop_panel").html(content)
    d3.selectAll(".pin").on("click", (d,i) -> that.pin(d,i,this))

    # @links = d3.layout.tree().links(@links);
    # @force.start()

  pin: (data, i, element) =>
    key = element.parentNode.previousSibling.innerHTML
    @label_node(@focused_node, @focused_node_data[key])

  label_node: (node, value) =>
    # node.append("text")
    #   .text(value)
    #   .attr("dx", 12)
    #   .attr("dy", ".35em")
    # console.log node

  # fix node so it is free from force
  dragstart: (data, i, element) =>
    data.fixed = true

  dragmove: (data, i, element) =>
    data.px += d3.event.dx
    data.py += d3.event.dy
    data.x += d3.event.dx
    data.y += d3.event.dy

  dragend: (data, i, element) =>
    @force.resume()

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

  key_stroke: () =>
    if d3.event?
      # Focus in on node and group them, children
      if (d3.event.keyCode == 65)
        node_name = @focused_node_data.DOMNodeName
        @circles.each( (d,i) ->
          if d.DOMNodeName == node_name
            console.log node_name
        )
      if (d3.event.keyCode == 67)
        # Show or hide children
        if @focused_node_data?
          if @focused_node_data.children.length isnt 0
            @hide_children null
          else if @focused_node_data._children.length isnt 0
            @show_children null

  # Recurse through children and hide nodes
  hide_children: (children) =>
    unless children?
      @focused_node.select("circle").attr("fill", "darkred")
      @focused_node.select("circle").attr("stroke", "darkred")
      children = @focused_node_data.children
      # Copy flattened children to buffer
      @focused_node_data["_children"] = children
      @focused_node_data["children"] = []
    for node in children
      # Depth first, recurse through children
      @hide_children node.children

      # Do not display child lines or nodes
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

  show_children: (children) =>      
    parent = false
    unless children?
      parent = true
      @focused_node.select("circle").attr("fill", "#d84b2a")
      @focused_node.select("circle").attr("stroke", "#d84b2a")
      children = @focused_node_data._children
      # Copy flattened children to buffer
      @focused_node_data["children"] = children
      @focused_node_data["_children"] = []
    for node in children
      # Depth first, recurse through children
      @show_children node.children

      that = this
      # Do not display child lines or nodes
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

$ ->
  chart = null

  render_vis = (xml) ->
    chart = new XMLSchema xml
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()

  d3.xml "data/AERL-short.ifc.xml", render_vis

