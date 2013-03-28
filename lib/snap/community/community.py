import json
import os
import hashlib
import subprocess
from bottle import route, run, request, static_file, template

@route('/community', method='POST')
def index():
    clusters = []
    cluster_map = {}

    tag = 'cache/comm_output_%s.txt' % hashlib.md5().update(request.body.read())
    if os.path.exists(tag):
        return static_file(tag)

    request.body.seek(0)

    try:
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

    # (cache and) output json
    json = json.dumps({'status': True, 'communities': clusters})
    cache = open(tag, 'w+')
    cache.write(json)
    cache.close()

    return json

run(host='localhost', port=8080)