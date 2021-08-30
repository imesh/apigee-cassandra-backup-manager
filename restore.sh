#!/bin/bash
set -e

SNAPSHOT_NAME=$1
if [ -z "$SNAPSHOT_NAME" ]; then
    echo "Usage: ./restore.sh {snapshot-name}"
    exit 1
fi

source config.sh

function restore_backup() {
    CASSANDRA_POD_NAME=$1
    echo "[${CASSANDRA_POD_NAME}] INFO: Copying cql script to the pod..."
    kubectl cp ./${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema.cql cqlsh:/tmp/${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema.cql

    echo "[${CASSANDRA_POD_NAME}] INFO: Executing cql script..."
    kubectl exec cqlsh -- cqlsh ${CASSANDRA_POD_NAME}.apigee-cassandra-default.${APIGEE_NAMESPACE}.svc.cluster.local -u ${CASSANDRA_DB_USER} -p ${CASSANDRA_DB_PASSWORD} --ssl -f /tmp/${CASSANDRA_POD_NAME}-${SNAPSHOT_NAME}-schema.cql || true

    echo "[${CASSANDRA_POD_NAME}] INFO: Copying Cassandra snapshot file to the pod..."
    TAR_FILE_NAME="${CASSANDRA_POD_NAME}-backup-${SNAPSHOT_NAME}.tgz"
    TAR_FILE_PATH="/opt/apigee/data/${TAR_FILE_NAME}"
    kubectl -n ${APIGEE_NAMESPACE} cp ./${TAR_FILE_NAME} ${CASSANDRA_POD_NAME}:${TAR_FILE_PATH}

    echo "[${CASSANDRA_POD_NAME}] INFO: Extracting Cassandra snapshot tar file in pod..."
    kubectl -n ${APIGEE_NAMESPACE} exec ${CASSANDRA_POD_NAME} -- bash -c "tar -xvf ${TAR_FILE_PATH} --directory /"

    echo "[${CASSANDRA_POD_NAME}] INFO: Deleting Cassandra snapshot tar file in the pod..."
    kubectl -n ${APIGEE_NAMESPACE} exec ${CASSANDRA_POD_NAME} -- sh -c "rm ${TAR_FILE_PATH}"

    echo "[${CASSANDRA_POD_NAME}] INFO: Restoring Cassandra backup..."
    kubectl -n ${APIGEE_NAMESPACE} cp ./../../pod-restore-snapshot.sh ${CASSANDRA_POD_NAME}:/opt/apigee/restore-snapshot.sh
    kubectl -n ${APIGEE_NAMESPACE} exec ${CASSANDRA_POD_NAME} -- bash /opt/apigee/restore-snapshot.sh ${SNAPSHOT_NAME} ${CASSANDRA_DB_USER} ${CASSANDRA_DB_PASSWORD}
    echo "[${CASSANDRA_POD_NAME}] INFO: DONE!"
}

echo "Snapshot: ${SNAPSHOT_NAME}"
echo "Apigee Namespace: ${APIGEE_NAMESPACE}"
echo "The Apigee Cassandra restoration process should be executed on a blank Cassandra database. Hence, a new Apigee runtime should be created on a new Kubernetes namespace for this task."
read -p "Does this namespace \"${APIGEE_NAMESPACE}\" meet above requirement (y/n)? " -n 1 -r
echo    # move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell but don't exit interactive shell
fi

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

pushd ./snapshots/${SNAPSHOT_NAME}
for CASSANDRA_POD_NAME in `kubectl -n ${APIGEE_NAMESPACE} get pods -l app=apigee-cassandra -o json |  jq -r '.items[] | .metadata.name'` ; do
    echo "Apigee Cassandra pod: ${CASSANDRA_POD_NAME}"
    restore_backup ${CASSANDRA_POD_NAME}
done
popd

echo "INFO: Deleting cqlsh pod..."
kubectl delete pod cqlsh &> /dev/null
echo "INFO: DONE!"