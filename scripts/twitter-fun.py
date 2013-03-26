import twitter
import hashlib
import sys

def safe(str):
    if str is not None:
        return str
    else:
        return ''

def screen_name(sc):
    return hashlib.md5(sc).hexdigest()[:8]

api = twitter.Api(       consumer_key='jB7yF8qSUUX1XQQrnecQ',
                      consumer_secret='vVpf89fdsPZ5sBk65Fvw6uXSYQ4SrU5GrVO1SHw',
                     access_token_key='14747228-2NuSYGUzcEe4nlBoLjgpZdIpg1TuF5v9icGNTuKT0',
                  access_token_secret='p7zBA0saOngXD0GPyRhnDBHIlZNYdJDsGmKHYywu4')

ppl = api.GetFollowers(user=twitter.User(sys.argv[1]))
count = 1

for person in ppl:
    print 'Person_' + str(count) + ', ' + \
          '@' + screen_name(safe(person.screen_name)) + ', ' + \
          safe(person.location) + ', ' + \
          safe(person.lang) + ', ' + \
          safe(person.created_at)
    count += 1




