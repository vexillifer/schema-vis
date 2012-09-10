for file in fnames:
    links[file] = []
    f = open(file)
    for line in f.readlines():
        while True:
            p = line.partition('<a href="http://')[2]
            if p=='':
                break
            url, _, line = p.partition('\">')
            links[file].append(url)
    f.close()