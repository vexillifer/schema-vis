import json
import subprocess
from bottle import route, run, request, template

@route('/community', method='POST')
def index():
    clusters = []
    cluster_map = {}

    try:
        # Requires community.cpp be tweaked so that
        # input is read from stdin and output goes to stdout, no files!!!!
        output = subprocess.check_output('./community -a:1', stdin=request.body)
    except:
        return json.dumps({'status': False})
    
    lines = map(lambda x: None if x[0] == '#' else x.strip().split(' '),  output.split('\n'))
    
    # bucket the nodes
    for line in lines:
        if line != None:
            if not line[1] in c_map:
                c_map[line[1]] = []
            c_map[line[1]].append(line[0])

    # collapse buckets into a list
    for cluster in c_map:
        clusters.append(c_map[cluster])

    # output json
    return json.dumps({'status': True, 'communities': clusters})

run(host='localhost', port=8080)