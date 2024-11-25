#!/bin/bash
GREEN='\033[0;32m' 

# docker-compose up -d

# init config server
echo -e "${GREEN} init config server"
docker exec -it configSrv mongosh --port 27017 --eval '
    rs.initiate(
        {
            _id : "config_server",
            configsvr: true,
            members: [
            { _id : 0, host : "configSrv:27017" }
            ]
        }
    );
    exit();
'

sleep 1

# init shards with replic
echo -e "${GREEN} init shards"
docker exec -it shard1 mongosh --port 27018 --eval '
    rs.initiate(
        {
        _id : "shard1",
        members: [
            { _id : 0, host : "shard1:27018" },
            { _id : 1, host : "shard1r1:27022" },
            { _id : 2, host : "shard1r2:27023" }
        ]
        }
    );
    exit();
'

sleep 1

docker exec -it shard2 mongosh --port 27019 --eval '
    rs.initiate(
        {
        _id : "shard2",
        members: [
            { _id : 1, host : "shard2:27019" },
            { _id : 2, host : "shard2r1:27024" },
            { _id : 3, host : "shard2r2:27025" }
            ]
        }
    );
    exit();
'

sleep 1

# init router
echo -e "${GREEN} init router"
docker exec -it mongos_router mongosh --port 27020 --eval '
    sh.addShard("shard1/shard1:27018");
    sh.addShard("shard2/shard2:27019");

    sh.enableSharding("somedb");
    sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

    exit();
'

sleep 1

# populate db
echo -e "${GREEN} populate db"
docker exec -it mongos_router mongosh --port 27020 somedb --eval '
    for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})

    db.helloDoc.countDocuments()
    exit();
'

# show records in shard 1
echo -e "${GREEN} show records in shard 1"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
    use somedb
    db.helloDoc.countDocuments()
EOF

# show records in shard 2
echo -e "${GREEN} show records in shard 2"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
    use somedb
    db.helloDoc.countDocuments()
EOF




