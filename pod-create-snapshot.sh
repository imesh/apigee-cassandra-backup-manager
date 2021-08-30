#!/bin/bash
# A bash script for capturing a Cassandra snapshot in apigee-cassandra
# pods.
# How to execute:
# 1. Copy this script to an apigee-cassandra pod.
# 2. Execute this script by providing a snapshot name and cassandra
#    db_user credentials.
# 3. Once executed, a snapshot will be created, all snapshot folders
#    will be packaged into a tar file and the snapshot will be deleted.
# 4. Copy the tar file the local machine and delete the generated tar
#    file from the pod.
#
# References: 
# Taking a snapshot: https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupTakesSnapshot.html
# Deleting a snapshot: https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupDeleteSnapshot.html

set -e

SNAPSHOT_NAME=$1
CASSANDRA_DB_USER=$2
CASSANDRA_DB_PASSWORD=$3
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

if [ -z "$SNAPSHOT_NAME" ] || [ -z "$CASSANDRA_DB_USER" ] || [ -z "$CASSANDRA_DB_PASSWORD" ]; then
    echo "Usage: ${SCRIPT_NAME} {SNAPSHOT_NAME} {CASSANDRA_DB_USER} {CASSANDRA_DB_PASSWORD}"
    exit 1
fi

TAR_FILE_PATH="/opt/apigee/data/${POD_NAME}-backup-${SNAPSHOT_NAME}.tgz"
TOKENS_FILE="/tmp/tokens.txt"
TOKENS=$("${CASSANDRA_HOME}"/bin/nodetool -u ${CASSANDRA_DB_USER} -pw ${CASSANDRA_DB_PASSWORD} ring | grep "${POD_IP}" | awk '{print $8}' | tr '\n' ', ')
echo "${TOKENS}" > "${TOKENS_FILE}"

echo "[${POD_NAME}] INFO: Creating snapshot: ${SNAPSHOT_NAME}"
"$CASSANDRA_HOME"/bin/nodetool -u ${CASSANDRA_DB_USER} -pw $CASSANDRA_DB_PASSWORD -h localhost snapshot -t "${SNAPSHOT_NAME}"
echo "[${POD_NAME}] INFO: Snapshot created: ${SNAPSHOT_NAME}"

echo "[${POD_NAME}] INFO: Creating snapshot tar file: ${SNAPSHOT_NAME}"
SNAPSHOT_S=$(find "${CASSANDRA_DATA}" -name snapshots)
nice -n 16 tar -h -zcf ${TAR_FILE_PATH} ${SNAPSHOT_S} "${TOKENS_FILE}"
echo "[${POD_NAME}] INFO: Snapshot tar file generated: ${TAR_FILE_PATH}"

echo "[${POD_NAME}] INFO: Clearing snapshot: ${SNAPSHOT_NAME}"
"$CASSANDRA_HOME"/bin/nodetool -u ${CASSANDRA_DB_USER} -pw $CASSANDRA_DB_PASSWORD -h localhost clearsnapshot -t "${SNAPSHOT_NAME}"
echo "[${POD_NAME}] INFO: Snapshot cleared: ${SNAPSHOT_NAME}"
