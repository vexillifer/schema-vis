# Schema Explorer

Schema Explorer visualizes XML files regardless of data or schema. This is a technical prototype and schema summarization has not yet been implemented.

<img src="https://raw.github.com/vexillifer/schema-vis/master/screenshots/screen-1.png" />


## Try it out!  
1. Check out the repository  

        git clone https://github.com/vexillifer/schema-vis.git

2. Place an XML file in data/  

3. Edit coffee/vis.coffee to point to your data:

        - d3.xml "data/AERL-short.ifc.xml", render_vis
        + d3.xml "data/YOURDATA", render_vis

4. Run an HTTP server, e.g.:

        python -m SimpleHTTPServer 8888

5. View the visualization:

        http://localhost:8888/index.html

