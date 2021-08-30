# Apigee hybrid Cassandra Backup Manager

## Background
In Apigee hybrid, Cassandra backups should be configured according to the [documentation](https://cloud.google.com/apigee/docs/hybrid/v1.5/backup-recovery) for periodically capturing Cassandra backups either using Google Cloud Storage buckets or using a SSH server (VM). Apigee has automated this operation using apigee-cassandra-backup-utility. If it is required to capture a Cassandra backup while the above configuration is not applied or when the Apigee controller in the runtime plane is in an inconsistent state, this approach can be used. 

This tool was written using the same approach used by apigee-cassandra-backup-utility and standard Cassandra guidelines of capturing snapshots, deleting snapshots and restoring them:

 - [Taking a snapshot in Cassandra 3.x by Datastax](https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupTakesSnapshot.html)
 - [Deleting a snapshot in Cassandra 3.x by Datastax](https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupDeleteSnapshot.html)
 - [Restoring from a snapshot in Cassandra 3.x by Datastax](https://docs.datastax.com/en/cassandra-oss/3.x/cassandra/operations/opsBackupSnapshotRestore.html)



## Disclaimer
Please note that this is not a Google product. Use this at your own risk.

## Apigee hybrid versions supported
This tool was verified on following releases:
- Apigee hybrid 1.3.4

## How to Backup

1. Take a copy of this Github repository and switch to the `apigee-hybrid-cassandra-backup-manager` directory:
   ```
   git clone https://github.com/imesh/apigee-hybrid-cassandra-backup-manager
   cd apigee-hybrid-cassandra-backup-manager/
   ```

2. Configure [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) to point to your Apigee hybrid Kubernetes cluster.

3. Update `config.sh` file and set Apigee namespace and Cassandra ddl_user credentials:
   ```
   APIGEE_NAMESPACE=apigee
   CASSANDRA_DB_USER=ddl_user
   CASSANDRA_DB_PASSWORD=#password
   ```

4. Execute `backup.sh` bash script:
   ```
   ./backup.sh
   ```

5. Verify the contents of the cql file and Apigee Cassandra snapshot tar file generated in the `./snapshots/[SNAPSHOT-NAME]/` directory.

## How to Restore

1. Configure [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) to point to your Apigee hybrid Kubernetes cluster.

2. Create a new Kubernetes namespace:
   ```
   kubectl create namespace [NEW-NAMESPACE]
   ```

3. Update `config.sh` file and set the new Apigee namespace and Cassandra ddl_user credentials:
   ```
   APIGEE_NAMESPACE=#new namespace
   CASSANDRA_DB_USER=ddl_user
   CASSANDRA_DB_PASSWORD=#password
   ```

4. Set the new Apigee namespace and a new instance id in the Apigee `overrides.yaml` file:
   ```yaml
   gcp:
     projectID: [project-id]
     region: "[gcp-region]"
   
   org: [apigee-hybrid-organization]
   namespace: [new-namespace]
   instanceID: "[new-instance-id]"
   ...
   ```

5. Create a new Apigee hybrid deployment in the new namespace created above and wait until it get activated:
   ```
   # create a new deployment
   apigeectl apply -f overrides/overrides.yaml

   # wait until all pods get activated
   watch apigeectl check-ready -f overrides/overrides.yaml
   ```

   Once a new deployment is started in a new namespace the following will happen:
   
   - API proxies and shared flows will be fetched from the control plane and deployed in apigee-runtime pods.
   - Apigee Cassandra database will be empty because new Cassandra pods will get new blank persistent volumes attached.
   - Apigee control plane will talk to both MART pods in the previous namespace and new namespace in round robin way if the deployment in the previous namespace is still running. If so, API requests served by the new namespace will return blank data. As a result, until the restoration process is complete, you may see blank data on the UI and through Apigee APIs time-to-time.

6. Identify the snapshot name from the `./snapshots/` folder.

7. Execute `restore.sh` bash script by passing the snapshot name:
   ```
   ./restore.sh [SNAPSHOT-NAME]
   ```

8. Verify the data restored to the Apigee Cassandra database through cqlsh:
   ```
   NEW_APIGEE_NAMESPACE=# set new apigee namespace

   # start apigee-hybrid-cassandra-client pod
   kubectl run -i --tty --restart=Never --rm --image google/apigee-hybrid-cassandra-client:1.0.0 cqlsh

   # connect to cqlsh
   cqlsh apigee-cassandra-default-0.apigee-cassandra-default.${NEW_APIGEE_NAMESPACE}.svc.cluster.local -u ddl_user -p iloveapis123 --ssl

   # list keyspaces and tables
   cqlsh> DESCRIBE TABLES;
   ```

   Once the data restoration process is verified, the previous Apigee namespace can be deleted. Please do this with caution, ensure that you have a latest Cassandra backup of that namespace and the Cassandra restoration process is verified. Afterwards, the new namespace can be used as the Apigee namespace of this deployment.
