class XMLParser
  constructor: () ->
    # network data
    @people = []
    @node_types = []
    @connections = []
    @index  = {}
    @attributes = []
    @name_map = {} # for anonymized names

  # Compute all nodes and links in network
  # 1) Create a node for each profile
  # 2) Create a link for each connection
  explore_network: (network, mode, node_limit, anonymize_names) =>    
    node = {}


    get_attributes = (attr, attributes, node) ->
      # look for attribute-esque children, add attribute to list
      if attr.firstChild != null and
      attr.firstChild.nodeType == 3 and
      attr.firstChild.nodeValue.trim() != ''
        attributes.push(attr.nodeName) if attr.nodeName not in attributes
        node[attr.nodeName] = attr.firstChild.nodeValue

        # for child in attr.querySelectorAll()

      # recursively iterate through children to find all possible attributes
      # for child in attr.childNodes
      #   # console.log child + " " + child.firstChild.nodeType if child.firstChild?
      #   get_attributes(child)

    # Add both company and person nodes of the XML DOM
    @node_types.push('person')
    @node_types.push('company')
    people = network.firstChild.querySelectorAll('company, person')
    connections = network.firstChild.querySelectorAll('connection')

    get_child_value = (parent, child) ->
      parent.querySelector(child)?.firstChild.nodeValue


    for person, i in people
      if node_limit? and i > node_limit then break
      node = {}
      name = null

      console.log @attributes["node name"]
      @attributes.push("node name") if @attributes["node name"]?
      node["node name"] = person.nodeName

      for attr in person.childNodes
        get_attributes(attr, @attributes, node)
        

        # attribute special cases
        switch attr.nodeName
          when "affiliations"
            # special case affiliations -- add in first affiliation by name
            node[attr.nodeName] = get_child_value(attr, "name")
          when "birthday_date"
            if attr.firstChild?.nodeValue.length > 5 # some are MM/DD and others MM/DD/YYYY
              date = attr.firstChild.nodeValue
              node["age"] = 2013 - parseInt(date.substring(date.length - 4));
          when "current_location"
            node['country'] = get_child_value(attr, "country")
            node['city'] = get_child_value(attr, "city")
            node['state'] = get_child_value(attr, "state")
          when "education"
            node['school']  = get_child_value(attr, "school name")
            node['major']  = get_child_value(attr, "concentration name")
          when "hometown_location"
            if attr.firstChild?
              node['hometown'] = get_child_value(attr, "city") + ", "+get_child_value(attr, "state");
          when "languages"
            if node['languages'] == undefined
              node['languages'] = get_child_value(attr, "name")
          when "sports"
            node['sports'] = get_child_value(attr, "name")
          when "work"
            if node['work'] == undefined
              node['work'] = get_child_value(attr, "employer name")
          when "family"
            node['has_family'] = true
          when "name"
            name = attr.firstChild.nodeValue
            node['name_raw'] = name;
            if anonymize_names
              node['name'] = "Person " + i
            @name_map[name] = node['name']; # map from actual name to visible name
          when "relationship_status" #rename to shorter 'relationship'
            node["relationship"] = attr.firstChild?.nodeValue

          # twitter location truncated to first chunk before comma
          when "location"
            loc = node["location"]
            if loc? and loc.indexOf(",") > 0
              node["location"] = loc.substring(0,loc.indexOf(","))
      copy = $.extend({}, node)
      copy.DOMNodeName = copy.name

      copy.idx = i
      @index[name] = copy
      @people.push(copy)


    for connection in connections
      uid1 = connection.querySelector('uid1')?.firstChild.nodeValue
      uid2 = connection.querySelector('uid2')?.firstChild.nodeValue
      if uid1? and uid2?
        @connections.push([uid1, uid2])
