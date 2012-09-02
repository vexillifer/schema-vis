# Explores and visualizes XML data, schema agnostic
# Melsa Smith, Aug 2012

counter = 0

class XMLSchema
  constructor: (data) ->
    @width = 700
    @height = 500
    @data = data

    @nodes = []
    @links = []
    @circles = null
    @visualization = null

    @tooltip = CustomTooltip("node_tooltip", 240)
    @center = {x: @width / 2, y: @height / 2}
    @layout_gravity = -0.01
    @damper = 0.1
    @force = null

    this.explore_data @data, {}
    this.visualize()

  # Create node for parent and explore children and siblings
  # Use prevID to create links from child -> parent
  explore_data: (parent, prevNode) =>
    # Add current node
    node = {}
    link = {}

    if parent.nodeType == 1
      node["DOMNodeID"] = counter++
      node["DOMNodeName"] = parent.nodeName

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
    @links.push link unless jQuery.isEmptyObject(link)

    # Add first child node
    firstChild = parent.firstChild
    this.explore_data firstChild, node if firstChild?

    # Add next sibling
    sibling = parent.nextSibling 
    this.explore_data sibling, prevNode if sibling? 

  visualize: () =>
    @visualization = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    # Add a circle for each node and apply data
    @circles = @visualization.selectAll("circle")
      .data(@nodes, (d) -> d.DomParentID)

    that = this

    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => "#d84b2a")
      .attr("stroke-width", 2)
      .attr("stroke", (d) => "black")
      .attr("id", (d) -> "bubble_#{d.DOMParentID}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    @circles.transition().duration(2000).attr("r", (d) -> 15)

  charge: (d) -> 
    -200
    # -Math.pow(@radius, 2.0) / 8

  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .size([@width, @height])

      # define strength as relative distance

  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_split(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()    

  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha


  move_towards_split: (alpha) =>
    (d) =>
      if d.DOMParentID < 25
        target = {x: @width / 3, y: @height / 2}
      else 
        target = {x: 2 * @width / 3, y: @height / 2}

      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1


  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = ""
    for key, value of data
      console.log key 
      content += "<span class=\"name\">#{key}</span>" + 
        "<span class=\"value\"> #{value}</span><br/>"
    @tooltip.showTooltip(content,d3.event)

  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => "#d84b2a")
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (xml) ->
    chart = new XMLSchema xml
    chart.start()
    root.display_all()
  root.display_all = () =>
    chart.display_group_all()

  d3.xml "data/SDL.xml", render_vis

