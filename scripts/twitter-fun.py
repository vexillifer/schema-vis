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

# Instantiate the API
api = twitter.Api(       consumer_key='jB7yF8qSUUX1XQQrnecQ',
                      consumer_secret='vVpf89fdsPZ5sBk65Fvw6uXSYQ4SrU5GrVO1SHw',
                     access_token_key='14747228-2NuSYGUzcEe4nlBoLjgpZdIpg1TuF5v9icGNTuKT0',
                  access_token_secret='p7zBA0saOngXD0GPyRhnDBHIlZNYdJDsGmKHYywu4')

# In memory data (we'll output XML later)
count = 0
count_max = 50
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
  
  count = count + 1
  if count > count_max:
    break

  people[my_follower.name] = my_follower
  connections.append([root.name, my_follower.name])
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
print '     people: %d' % len(people.keys())
print 'connections: %d' % len(connections)
print

# dump it to XML
print '<?xml version="1.0" encoding="UTF-8"?>'
print '<network>'

for name in people:
  person = people[name]
  print ' <person>'
  try:
    print '   <name>%s</name>' % safe(person.name)
    print '   <locale>%s</locale>' % safe(person.location)
    print '   <lang>%s</lang>' % safe(person.lang)
    print '   <screen>%s</screen>' % safe(person.screen_name)
    print '   <created>%s</created>' % safe(person.created_at)
  except:
    # encoding woes...
    pass
  print ' </person>'

for connection in connections:
  print ' <connection>'
  try:
    print '   <uid1>%s</uid1>' % safe(connection[0])
    print '   <uid2>%s</uid2>' % safe(connection[1])
  except:
    pass
  print ' </connection>'

print '</network>'





