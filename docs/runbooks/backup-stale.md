# A database backup is stale, failed or too small

**Alerts:** `BackupStale` (no good backup for 26 hours, critical), `BackupLastRunFailed`, `BackupTooSmall`. **Type:** data, SEV2 or worse; a write-up is always required.

The job is `/opt/databases/backup.sh` on the database VM (`ssh database`), run daily at 02:00 by cron. It makes four dumps (`postgres`, `mongodb`, `redis`, `minio`), keeps the last good time and size of each in `/opt/databases/backups/.state/`, and publishes them for Prometheus. Details and metrics: [monitoring-phase5.md](../monitoring-phase5.md#backups).

## First five minutes

1. Open the incident and **Acknowledge**. Note which job (`backup` label) and the time of the last good one.
2. Read why: `ssh database 'tail -n 60 /var/log/db-backup.log'`. The usual causes are a container down (`docker ps`), a full disk (`df -h /opt/databases`), a changed password (the MySQL job failed for weeks for this reason), or the Redis save not finishing.
3. Run it by hand: `ssh database 'sudo /opt/databases/backup.sh; echo exit=$?'`, then `cat /var/lib/node_exporter/textfile_collector/db_backup.prom`. You want `backup_last_run_success` 1 for every job and a fresh `backup_last_success_timestamp_seconds`.
4. If it fails again, fix the cause you saw in step 2 (start the container, free space, correct the password in the playbook's variables and re-run `database-setup.yml`). Do not edit the script on the VM by hand; change `database-setup.yml` so the fix survives.
5. **Copy the newest files off the VM now**, to your laptop or another machine: `scp database:/opt/databases/backups/*.gz .` (and the Mongo tarball). The backups live on the same VM and the same single SSD as the data, so a failure of either takes both.
6. **Prove one restores.** On a scratch machine (never on the database VM): start empty `postgres:16` and `mongo:8.2` containers and restore the newest `postgres_*.sql.gz` and `mongodb_*.tar.gz` as in "Monthly restore test" of [monitoring-phase5.md](../monitoring-phase5.md). Check a known count (users in Mongo, issues in GlitchTip). A file that exists is not a backup until it restores.

## Then

- `BackupTooSmall`: open the file and compare with the one before in `/opt/databases/backups`. A dump under half its usual size is usually a failed dump that still wrote something. Treat the previous file as the latest good one and run step 3 again.
- Write the date and result of any restore test at the bottom of the table in monitoring-phase5.md.

## Do not

- Do not delete old backups to make space until you have a good new one.
- Do not run a restore on the database VM.
- Do not silence `BackupStale`: it fires once a day at most and means no good backup exists.

## Afterwards

Resolve once the metrics are green, then write it up: when it started, the cause, how long there was no good backup, and whether the data was ever at risk. If the cause was a single point of failure (same VM, same SSD), the follow-up is the off-machine copy, which is still an open decision in the observability plan.
