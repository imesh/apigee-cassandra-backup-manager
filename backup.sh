#!/bin/bash
set -e

source config.sh

function create_backup() {
    CASSANDRA_POD_NAME=$1

    echo "[${CASSANDRA_POD_NAME}] INFO: Exporting schema cql..."
    kubectl exec cqlsh -- bash -c "/usr/bin/cqlsh apigee-cassandra-default-0.apigee-cassandra-default.apigee.svc.cluster.local -u ${CASSANDRA_DB_USER} -p ${CASSANDRA_DB_PASSWORD} --ssl -e 'desc schema;'" > ${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema-tmp.cql

    cat ${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema-tmp.cql | sed 's/pod "cqlsh" deleted//g' > ${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema.cql
    rm ${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema-tmp.cql
    echo "[${CASSANDRA_POD_NAME}] INFO: Exchema cql exported: $(pwd)/${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema.cql"

    echo "[${CASSANDRA_POD_NAME}] INFO: Creating a Cassandra snapshot in the pod..."
    kubectl -n ${APIGEE_NAMESPACE} cp ./../../pod-create-snapshot.sh ${CASSANDRA_POD_NAME}:/opt/apigee/create-snapshot.sh
    kubectl -n ${APIGEE_NAMESPACE} exec ${CASSANDRA_POD_NAME} -- bash /opt/apigee/create-snapshot.sh ${SNAPSHOT_NAME} ${CASSANDRA_DB_USER} ${CASSANDRA_DB_PASSWORD}
    echo "[${CASSANDRA_POD_NAME}] INFO: A Cassandra snapshot and snapshot tar file created in the pod"

    echo "[${CASSANDRA_POD_NAME}] INFO: Copying Cassandra snapshot file from the pod to the local machine..."
    TAR_FILE_NAME=${CASSANDRA_POD_NAME}-backup-${SNAPSHOT_NAME}.tgz
    TAR_FILE_PATH="/opt/apigee/data/${TAR_FILE_NAME}"
    kubectl -n ${APIGEE_NAMESPACE} cp ${CASSANDRA_POD_NAME}:${TAR_FILE_PATH} ./${TAR_FILE_NAME}
    echo "[${CASSANDRA_POD_NAME}] INFO: Cassandra snapshot file copied: $(pwd)/${TAR_FILE_NAME}"

    echo "[${CASSANDRA_POD_NAME}] INFO: Deleting Cassandra snapshot file created in the pod..."
    kubectl -n ${APIGEE_NAMESPACE} exec ${CASSANDRA_POD_NAME} -- sh -c "rm ${TAR_FILE_PATH}"
    echo "[${CASSANDRA_POD_NAME}] INFO: Cassandra snapshot file created in the pod was deleted"
    echo "[${CASSANDRA_POD_NAME}] INFO: Backup DONE!"
}

SNAPSHOT_NAME=snapshot-$(date '+%Y-%m-%d-%H-%M-%S')
echo "Snapshot: ${SNAPSHOT_NAME}"
echo "Apigee Namespace: ${APIGEE_NAMESPACE}"

echo "INFO: Check the availability of the cqlsh pod..."
set +e
kubectl get pods cqlsh &> /dev/null
EXIT_CODE=$?
set -e
if [ $EXIT_CODE -ne 0 ]; then
    echo "INFO: Creating cqlsh pod..."
    kubectl run --restart=Never --image google/apigee-hybrid-cassandra-client:1.0.0 cqlsh -- -c "tail -f /dev/null"
    sleep 5
else
    echo "INFO: The cqlsh pod already exists..."
fi

mkdir ./snapshots/${SNAPSHOT_NAME}
pushd ./snapshots/${SNAPSHOT_NAME} > /dev/null
for CASSANDRA_POD_NAME in `kubectl -n ${APIGEE_NAMESPACE} get pods -l app=apigee-cassandra -o json |  jq -r '.items[] | .metadata.name'` ; do
    echo "Apigee Cassandra pod: ${CASSANDRA_POD_NAME}"
    create_backup ${CASSANDRA_POD_NAME}
done
popd > /dev/null

echo "INFO: Deleting cqlsh pod..."
kubectl delete pod cqlsh &> /dev/null
echo "INFO: DONE!"