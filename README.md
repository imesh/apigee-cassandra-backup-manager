# Apigee hybrid Cassandra Backup Manual Execution

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
   CASSANDRA_DB_PASSWORD=# set ddl_user password here
   ```

4. Execute `backup.sh` bash script:
   ```
   ./backup.sh
   ```

   An example output:
   ```
   ./backup.sh
   Snapshot: snapshot-2021-08-31-15-45-20
   Apigee Namespace: apigee
   INFO: Check the availability of the cqlsh pod...
   INFO: The cqlsh pod already exists...
   Apigee Cassandra pod: apigee-cassandra-default-0
   [apigee-cassandra-default-0] INFO: Exporting schema cql...
   [apigee-cassandra-default-0] INFO: Exchema cql exported: /Users/imesh/apigee/hybrid/cassandra/apigee-hybrid-cassandra-backup-manager/cassandra-backups/snapshots/snapshot-2021-08-31-15-45-20/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql
   [apigee-cassandra-default-0] INFO: Creating a Cassandra snapshot in the pod...
   [apigee-cassandra-default-0] INFO: Creating snapshot: snapshot-2021-08-31-15-45-20
   Requested creating snapshot(s) for [all keyspaces] with snapshot name [snapshot-2021-08-31-15-45-20] and options {skipFlush=false}
   Snapshot directory: snapshot-2021-08-31-15-45-20
   [apigee-cassandra-default-0] INFO: Snapshot created: snapshot-2021-08-31-15-45-20
   [apigee-cassandra-default-0] INFO: Creating snapshot tar file: snapshot-2021-08-31-15-45-20
   tar: Removing leading `/' from member names
   [apigee-cassandra-default-0] INFO: Snapshot tar file generated: /opt/apigee/data/apigee-cassandra-default-0-backup-snapshot-2021-08-31-15-45-20.tgz
   [apigee-cassandra-default-0] INFO: Clearing snapshot: snapshot-2021-08-31-15-45-20
   Requested clearing snapshot(s) for [all keyspaces] with snapshot name [snapshot-2021-08-31-15-45-20]
   [apigee-cassandra-default-0] INFO: Snapshot cleared: snapshot-2021-08-31-15-45-20
   [apigee-cassandra-default-0] INFO: A Cassandra snapshot and snapshot tar file created in the pod
   [apigee-cassandra-default-0] INFO: Copying Cassandra snapshot file from the pod to the local machine...
   tar: Removing leading `/' from member names
   [apigee-cassandra-default-0] INFO: Cassandra snapshot file copied: /Users/imesh/apigee/hybrid/cassandra/apigee-hybrid-cassandra-backup-manager/cassandra-backups/snapshots/snapshot-2021-08-31-15-45-20/apigee-cassandra-default-0-backup-snapshot-2021-08-31-15-45-20.tgz
   [apigee-cassandra-default-0] INFO: Deleting Cassandra snapshot file created in the pod...
   [apigee-cassandra-default-0] INFO: Cassandra snapshot file created in the pod was deleted
   [apigee-cassandra-default-0] INFO: Backup DONE!
   INFO: Deleting cqlsh pod...
   INFO: DONE!
   ```

5. Verify the contents of the cql file and Apigee Cassandra snapshot tar file generated in the `./snapshots/[SNAPSHOT-NAME]/` directory:
   ```
   # verify the contents of the cql file
   cat cassandra-backups/snapshots/${SNAPSHOT_NAME}/${CASSANDRA_POD_NAME}-snapshot-2021-08-31-15-45-20-schema.cql

   # verify the contents of the snapshot tar file
   tar -tvf cassandra-backups/snapshots/${SNAPSHOT_NAME}/${CASSANDRA_POD_NAME}-backup-${SNAPSHOT_NAME}.tgz
   ```

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

   An example output:
   ```
   ./restore.sh snapshot-2021-08-31-15-45-20
   Snapshot: snapshot-2021-08-31-15-45-20
   Apigee Namespace: apigee
   The Apigee Cassandra restoration process should be executed on a blank Cassandra database. Hence, a new Apigee runtime should be created on a new Kubernetes namespace for this task.
   Does this namespace "apigee" meet above requirement (y/n)? y
   INFO: Check the availability of the cqlsh pod...
   INFO: The cqlsh pod already exists...
   Apigee Cassandra pod: apigee-cassandra-default-0
   [apigee-cassandra-default-0] INFO: Copying cql script to the pod...
   [apigee-cassandra-default-0] INFO: Executing cql script...
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:3:AlreadyExists: Keyspace 'kvm_hybrid_project_id_hybrid' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:31:AlreadyExists: Table 'kvm_hybrid_project_id_hybrid.kvm_map_keys_descriptor' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:58:AlreadyExists: Table 'kvm_hybrid_project_id_hybrid.kvm_map_entry' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:85:AlreadyExists: Table 'kvm_hybrid_project_id_hybrid.kvm_map_descriptor' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:87:AlreadyExists: Keyspace 'kms_hybrid_project_id_hybrid' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:109:AlreadyExists: Table 'kms_hybrid_project_id_hybrid.company_developer_sorted_by_email' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:143:AlreadyExists: Table 'kms_hybrid_project_id_hybrid.app' already exists
   ...
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:1057:AlreadyExists: Table 'perses.marked_entity' already exists
   /tmp/apigee-cassandra-default-0-snapshot-2021-08-31-15-45-20-schema.cql:1081:AlreadyExists: Table 'perses.entity_count' already exists
   command terminated with exit code 2
   [apigee-cassandra-default-0] INFO: Copying Cassandra snapshot file to the pod...
   [apigee-cassandra-default-0] INFO: Extracting Cassandra snapshot tar file in pod...
   opt/apigee/data/apigee-cassandra/data/perses/marked_entity-85c471f0017811ecb0fa61572cdfaec5/snapshots/
   opt/apigee/data/apigee-cassandra/data/perses/marked_entity-85c471f0017811ecb0fa61572cdfaec5/snapshots/snapshot-2021-08-31-15-45-20/
   opt/apigee/data/apigee-cassandra/data/perses/marked_entity-85c471f0017811ecb0fa61572cdfaec5/snapshots/snapshot-2021-08-31-15-45-20/manifest.json
   opt/apigee/data/apigee-cassandra/data/perses/marked_entity-85c471f0017811ecb0fa61572cdfaec5/snapshots/snapshot-2021-08-31-15-45-20/schema.cql
   ...
   opt/apigee/data/apigee-cassandra/data/cache_hybrid_project_id_hybrid/cache_map_descriptor-526f1e41017811ecb0fa61572cdfaec5/snapshots/snapshot-2021-08-31-15-45-20/md-7-big-Summary.db
   opt/apigee/data/apigee-cassandra/data/cache_hybrid_project_id_hybrid/cache_map_descriptor-526f1e41017811ecb0fa61572cdfaec5/snapshots/snapshot-2021-08-31-15-45-20/schema.cql
   tmp/tokens.txt
   [apigee-cassandra-default-0] INFO: Deleting Cassandra snapshot tar file in the pod...
   [apigee-cassandra-default-0] INFO: Restoring Cassandra backup...
   [apigee-cassandra-default-0] INFO: Copying snapshot of ./apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_descriptor-70eae1d00a2211ec92d5c55959899199 to its data directory...
   mv: cannot stat './apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_descriptor-70eae1d00a2211ec92d5c55959899199/snapshots/snapshot-2021-08-31-15-45-20/*': No such file or directory
   [apigee-cassandra-default-0] INFO: Restoring table ./apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_descriptor-70eae1d00a2211ec92d5c55959899199...
   WARN  06:15:22,688 Small commitlog volume detected at /opt/apigee/data/apigee-cassandra/commitlog; setting commitlog_total_space_in_mb to 2494.  You can override this in cassandra.yaml
   WARN  06:15:22,865 Only 9.738GiB free across all data volumes. Consider adding more capacity to your cluster or removing obsolete snapshots
   Established connection to initial hosts
   Opening sstables and calculating sections to stream

   Summary statistics:
      Connections per host    : 3
      Total files transferred : 0
      Total bytes transferred : 0.000KiB
      Total duration          : 3820 ms
      Average transfer rate   : 0.000KiB/s
      Peak transfer rate      : 0.000KiB/s

   [apigee-cassandra-default-0] INFO: Table successfully restored: ./apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_descriptor-70eae1d00a2211ec92d5c55959899199
   [apigee-cassandra-default-0] INFO: Copying snapshot of ./apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_keys_descriptor-463ba4e0017811ecb0fa61572cdfaec5 to its data directory...
   [apigee-cassandra-default-0] INFO: Restoring table ./apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_keys_descriptor-463ba4e0017811ecb0fa61572cdfaec5...
   WARN  06:15:29,340 Small commitlog volume detected at /opt/apigee/data/apigee-cassandra/commitlog; setting commitlog_total_space_in_mb to 2494.  You can override this in cassandra.yaml
   WARN  06:15:29,455 Only 9.738GiB free across all data volumes. Consider adding more capacity to your cluster or removing obsolete snapshots
   Established connection to initial hosts
   Opening sstables and calculating sections to stream
   Streaming relevant part of /opt/apigee/data/apigee-cassandra/data/kvm_hybrid_project_id_hybrid/kvm_map_keys_descriptor-463ba4e0017811ecb0fa61572cdfaec5/md-1-big-Data.db  to [/10.112.3.30]
   progress: [/10.112.3.30]0:1/1 100% total: 100% 0.103KiB/s (avg: 0.103KiB/s)
   progress: [/10.112.3.30]0:1/1 100% total: 100% 0.000KiB/s (avg: 0.101KiB/s)

   Summary statistics:
      Connections per host    : 3
      Total files transferred : 1
      Total bytes transferred : 0.403KiB
      Total duration          : 3981 ms
      Average transfer rate   : 0.101KiB/s
      Peak transfer rate      : 0.103KiB/s

   ...

   [apigee-cassandra-default-0] INFO: Table successfully restored: ./apigee-cassandra/data/quota_hybrid_project_id_hybrid/timeseries_entry-5ea04db0017811ecb0fa61572cdfaec5
   [apigee-cassandra-default-0] INFO: Copying snapshot of ./apigee-cassandra/data/quota_hybrid_project_id_hybrid/expiring_counters-5ea04db1017811ecb0fa61572cdfaec5 to its data directory...
   [apigee-cassandra-default-0] INFO: Restoring table ./apigee-cassandra/data/quota_hybrid_project_id_hybrid/expiring_counters-5ea04db1017811ecb0fa61572cdfaec5...
   WARN  06:28:25,962 Small commitlog volume detected at /opt/apigee/data/apigee-cassandra/commitlog; setting commitlog_total_space_in_mb to 2494.  You can override this in cassandra.yaml
   WARN  06:28:26,124 Only 9.734GiB free across all data volumes. Consider adding more capacity to your cluster or removing obsolete snapshots
   Established connection to initial hosts
   Opening sstables and calculating sections to stream

   Summary statistics:
      Connections per host    : 3
      Total files transferred : 0
      Total bytes transferred : 0.000KiB
      Total duration          : 3821 ms
      Average transfer rate   : 0.000KiB/s
      Peak transfer rate      : 0.000KiB/s

   [apigee-cassandra-default-0] INFO: Table successfully restored: ./apigee-cassandra/data/quota_hybrid_project_id_hybrid/expiring_counters-5ea04db1017811ecb0fa61572cdfaec5
   [apigee-cassandra-default-0] INFO: Restore completed: snapshot-2021-08-31-15-45-20
   [apigee-cassandra-default-0] INFO: DONE!
   INFO: Deleting cqlsh pod...
   INFO: DONE!
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
