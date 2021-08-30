#!/bin/bash
# A bash script for restoring Cassandra keyspaces from a 
# snapshot in apigee-cassandra pods.
# How to execute: 
# 1. Copy this script to an apigee-cassandra pod.
# 2. Copy the snapshot tar file to the pod, extract it 
#    and delete the tar file from the pod.
# 3. Execute this script with the snapshot name cassandra 
#    db_user credentials
#
# References: 
# Restoring from a snapshot: https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupSnapshotRestore.html

set -e

SNAPSHOT_NAME=$1
CASSANDRA_DB_USER=$2
CASSANDRA_DB_PASSWORD=$3

if [ -z "$SNAPSHOT_NAME" ] || [ -z "$CASSANDRA_DB_USER" ] || [ -z "$CASSANDRA_DB_PASSWORD" ]; then
    echo "Usage: ${SCRIPT_NAME} {SNAPSHOT_NAME} {CASSANDRA_DB_USER} {CASSANDRA_DB_PASSWORD}"
    exit 1
fi

cd /opt/apigee/data
source /opt/apigee/apigee-cassandra/ssl/truststorepassword.txt
source /opt/apigee/apigee-cassandra/ssl/keystorepassword.txt

# get all tables found in keyspaces
tables=$(find ./ -mindepth 4 -maxdepth 4 -type d -not -path "./apigee-cassandra/data/system*/*" -prune)
for table in $tables
do
  # move sstable files found in the snapshot directory to the data directory
  echo "[${POD_NAME}] INFO: Copying snapshot of $table to its data directory..." 
  mv "$table"/snapshots/"$SNAPSHOT_NAME"/* "$table"/ || true
  # execute sstableloader and import data
  echo "[${POD_NAME}] INFO: Restoring table $table..." 
  sstableloader -d "${POD_IP}" --truststore /opt/apigee/apigee-cassandra/ssl/truststore.p12 --truststore-password "${CASSANDRA_TRUSTSTORE_PASSWORD}" --keystore-password "${CASSANDRA_KEYSTORE_PASSWORD}" --keystore /opt/apigee/apigee-cassandra/ssl/keystore.p12 -cph 3 -v -u "${CASSANDRA_DB_USER}" -pw "${CASSANDRA_DB_PASSWORD}" --ssl-storage-port 7001 -prtcl TLS -f "${CASSANDRA_HOME}"/conf/cassandra.yaml "$table"
  if [ $? != 0 ]
  then
    echo "[${POD_NAME}] ERROR: Table restoration failed: $table"
   else
    echo "[${POD_NAME}] INFO: Table successfully restored: $table"
  fi
done
echo "[${POD_NAME}] INFO: Restore completed: ${SNAPSHOT_NAME}"
