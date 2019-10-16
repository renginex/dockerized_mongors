#!/bin/bash
# Mongo Replica Set with Authentication
# This script can be used to stand up a complete, secure three node Mongo replica set. In this example, we actually create a keyfile and docker-compose.yml, but you can generate your own keyfile and create your own docker-compose modified to your needs. While host/ports could be simplified because we're running this in docker-compose so the containers would be able to recognize each other internally, they're written here to mimic what it'd be like to have these nodes on different hosts. This working example helps to illustrate how these nodes work with each other.

# For testing purposes only so we can re-run our script and have it wipe our volumes out.
# docker-compose down && docker volume rm mongod1_data && docker volume rm mongod2_data && docker volume rm mongod3_data

# Set our variables to use through this script.
HOST_IP="<<IP_HERE>>"
ADMIN_USER=admin_user
ADMIN_PWD=admin_pwd
RS_ID=mongodrs1

# Create our initial node without authentication and add an admin user to it before bringing it down.
docker volume create mongod1_data
docker run -it -d --name mongod1 -p 27017:27017 -v mongod1_data:/data/db mongo
sleep 15 # Just want to give the node enough time to actually start.
docker exec -it mongod1 bash -c "printf 'use admin \n db.createUser({user: \"$ADMIN_USER\", pwd: \"$ADMIN_PWD\", roles:[{role: \"root\", db: \"admin\"}]})' | mongo" # We'll be writing lines and piping them into Mongo to execute our commands from the host. Note that we'll pretty much always use "printf" over "echo" because it can interperet our end lines, which need to feed into the Mongo shell as that's our only method of chaining Mongo commands in a single bash line.
docker rm -f mongod1 # Destroying the container won't destroy the changes we made since it's on a volume (mongod1_data).

# Generate a keyfile. For this example, we're going to give ahead and give it a static one. The next line is the command to use to generate a new keyfile.
# openssl rand -base64 756 > keyfile
cat > keyfile <<EOF
OkD8zqkhJIRSzTaTozhcwukVe9OY7qzkoTz8VV/vwc0qRH0LRpOo5L1ddGJS+/eM
w+4PE/s64VzPMo1SpLRe2Ib9aKNTatHHqpWyNQAPxtBYUpDC6+zMZrV1Kmwwary+
+QGUpglHTn/9bPN1hljrCne+rKjBNAtgkC8OzlMUT6RxtTnOiilOeoU9r3sqN9Cq
mjKd0CeKZhL+jMxv5ezFbQvlHQWthmkfYtTMWqDE7d1fni4ejZzzvyw1YnPdWvoa
/3sBF+AyG4dwLbmhiwDP4sCBwFdKznjwkOghP4hjlNBaK8acpqaKBOFhFlL4eCXq
ioXpl61CmyUPRoAMmWS9VyksDywfOgFlkHtpJd0gQ9dxXoFHMbq63nRB79eBPLWB
YNaG9RXSmWVt0My9mDyfxWQKBmbEGbAMNAfayUCZoUKgOu9Oh7XyUTiVtAHQudv5
sZXxmKP0SKgCkIPAo2W8/3JbBPl+j76Nt84aXhLoSwagIvCK2ZBeV/8wwQNrpa9L
8K0XFOUCHDWsqbzIW+xwyaSLirosy7xvp4maZc19Iv/5DSKbzT81UQPFV0/detm6
A2+hptLakjlI8QQkRavja9QpMtr2yMMX+9ujCadAOl6XvbLEH56jfEVRri8V3tvo
uLL4si6e1yYLOewR1ESAaIj2luj7v8/P+PMZpziEy6jyb/nbgFxcWqrdd0C9W52S
dblA6W+FeRaX2CC0svk4VApfy+NxvspxN9AicxvTf9VLa3pReI/0tyBPOJHsN3Ax
6a/ujXaz1AyTXM480REg29ctzoXLZOlaKUblryeASROmO8VIHystgJ85GUc1t/wS
xExk8I4pjmXF0/maHTijO3BNVq8F+Y5XOV9DSyiwBULmEQiaWA54wheHdQIEZns3
o2FDxQyIQWd5LTMGb1jgFS87nE9QDx4BZuln/lmwBI4Y10yVtWV/C5emJqN1skGG
BdOcZvKvhXJyp/UuHUCiW2A00DO/d7Knimt5AJ22EnXNI5bK
EOF
chmod 400 keyfile

# Create our docker-compose.yml with the additional replica set nodes.
docker volume create mongod2_data
docker volume create mongod3_data
cat > docker-compose.yml <<EOF
version: '2'
services:
  mongod1:
    container_name: mongod1
    image: mongo
    command: /bin/sh -c "mongod --replSet $RS_ID --keyFile /etc/keyfile --bind_ip 0.0.0.0 --port 27017"
    ports:
      - 27017:27017
    volumes:
      - mongod1_data:/data/db
      - ./keyfile:/etc/keyfile
  mongod2:
    container_name: mongod2
    image: mongo
    command: /bin/sh -c "mongod --replSet $RS_ID --keyFile /etc/keyfile --bind_ip 0.0.0.0 --port 27017"
    ports:
      - 27018:27017
    volumes:
      - mongod2_data:/data/db
      - ./keyfile:/etc/keyfile
  mongod3:
    container_name: mongod3
    image: mongo
    command: /bin/sh -c "mongod --replSet $RS_ID --keyFile /etc/keyfile --bind_ip 0.0.0.0 --port 27017"
    ports:
      - 27019:27017
    volumes:
      - mongod3_data:/data/db
      - ./keyfile:/etc/keyfile

volumes:
  mongod1_data:
    external: true
  mongod2_data:
    external: true
  mongod3_data:
    external: true
EOF

# Bring up all of our nodes with docker-compose.
docker-compose up -d
sleep 30

# Initiate the replica set.
docker exec -it mongod1 bash -c "printf 'db.getSiblingDB(\"admin\").auth(\"$ADMIN_USER\", \"$ADMIN_PWD\") \n rs.initiate({_id: \"$RS_ID\", members: [{ _id: 0, host: \"$HOST_IP:27017\" }, { _id: 1, host: \"$HOST_IP:27018\" }, { _id: 2, host: \"$HOST_IP:27019\" }]})' | mongo"
sleep 30

# Verify that it worked. You should see all three nodes under "members" and one should be in the state PRIMARY while the other two are SECONDARY. If you see nodes in the state STARTUP, they may need more time to be recognized and assigned.
docker exec -it mongod1 bash -c "printf 'db.getSiblingDB(\"admin\").auth(\"$ADMIN_USER\", \"$ADMIN_PWD\") \n rs.status()' | mongo"

# Now you're done! You have a secure Mongo replica set with three nodes!

# When you're ready to add this replica set to a cluster, all you have to do is add the "--shardsvr" flag to the mongod commands in your docker-compose, then just "docker-compose down and docker-compose up -d". This will restart the replica set nodes as shard servers, where they can then be added to a cluster.
