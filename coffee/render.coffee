
#= require SchemaVisualization
#= require XMLParser

root = exports ? this

# Run the visualization on an XML file
$ ->
  chart = null

  # interpret mode from ?dataset=x where x=1 facebook, x=2 twitter, x=?? testdata
  dataset = window.location.search.match("dataset=(.)");

  if dataset?
    if dataset[1] == "1"
      mode = "facebook"
    else if dataset[1] == "2"
      mode = "twitter"
    else
      mode = "test"
  else
    mode = "facebook"

  init = (mode) ->
    if mode == "facebook"
      data_file = "data/FB_combined.xml"
    else if mode =="twitter"
      data_file = "data/Twitter_2000.xml"
    else
      data_file = "data/test_data.xml"
    console.log "Using data from "+data_file

    d3.xml data_file, render_vis

  render_vis = (xml) ->
    if not xml?
      throw "Error reading data";

    chart = new SchemaVisualization(xml, mode)
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

    $("#subgraph_btn").click(() => chart.select_subgraph($("#prop_meta").data("node")))

    # Back button
    window.onpopstate = (e)   => chart.history_popstate(e)

  root.display_all = () =>
    chart.display()


  init(mode)

