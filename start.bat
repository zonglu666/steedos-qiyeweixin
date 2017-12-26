rem set DB_SERVER=192.168.0.21
set DB_SERVER=localhost
set MONGO_URL=mongodb://%DB_SERVER%/steedos
set MONGO_OPLOG_URL=mongodb://%DB_SERVER%/local
set MULTIPLE_INSTANCES_COLLECTION_NAME=workflow_instances
set ROOT_URL=http://office.steedos.com:3081/
meteor run --port 5000 --settings settings.json