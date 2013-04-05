import twitter
import hashlib
import sys

# Str safety
def safe(str):
    if str is not None:
        return str
    else:
        return ''

# Compute an anonymous screen name
def screen_name(sc):
    return hashlib.md5(sc).hexdigest()[:8]

# Only grab COUNT_MAX friends of seed user
count = 0
COUNT_MAX = 50

# Instantiate the API
api = twitter.Api(       consumer_key='jB7yF8qSUUX1XQQrnecQ',
                      consumer_secret='vVpf89fdsPZ5sBk65Fvw6uXSYQ4SrU5GrVO1SHw',
                     access_token_key='14747228-2NuSYGUzcEe4nlBoLjgpZdIpg1TuF5v9icGNTuKT0',
                  access_token_secret='p7zBA0saOngXD0GPyRhnDBHIlZNYdJDsGmKHYywu4')

# In memory data (we'll output XML later)
people = {}
connections = []

# This person is the root of out network
root = twitter.User(id=sys.argv[1], 
                    name=sys.argv[2], 
                    screen_name=sys.argv[1],
                    lang='',
                    location='',
                    created_at='')

people[root.name] = root

# Get mutual friends network for single person
my_followers = api.GetFollowers(user=root)
for my_follower in my_followers:

  people[my_follower.name] = my_follower
  connections.append([root.name, my_follower.name])

  count = count + 1
  if count > COUNT_MAX:
    break

  # Don't crawl crazy ass accounts (@ILoveBurritos, etc.)
  if my_follower.followers_count is not None and my_follower.followers_count < 300:
    try:
      followers = api.GetFollowers(user=my_follower)
      for follower in followers:
        
        people[follower.name] = follower
        connections.append([my_follower.name, follower.name])
    except:
      # oops, not authorized...
      pass

# Some stats (delete this from XML)  
print u'     people: %d' % len(people.keys())
print u'connections: %d' % len(connections)
print

# dump it to XML
print u'<?xml version="1.0" encoding="UTF-8"?>'
print u'<network>'

for name in people:
  p = people[name]
  print u' <person>'
  if hasattr(p, 'name') and p.name != None:
    print (u'   <name>%s</name>' % p.name).encode('utf-8')
  if hasattr(p, 'location') and p.location != None:
    print (u'   <location>%s</location>' % p.location).encode('utf-8')
  if hasattr(p, 'lang') and p.lang != None:
    print (u'   <lang>%s</lang>' % p.lang).encode('utf-8')
  if hasattr(p, 'screen') and p.screen != None:
    print (u'   <screen>%s</screen>' % p.screen_name).encode('utf-8')
  if hasattr(p, 'created_at') and p.created_at != None:
    print (u'   <created>%s</created>' % p.created_at).encode('utf-8')
  print ' </person>'

for connection in connections:
  print u' <connection>'
  print (u'   <uid1>%s</uid1>' % connection[0]).encode('utf-8')
  print (u'   <uid2>%s</uid2>' % connection[1]).encode('utf-8')
  print u' </connection>'

print u'</network>'





