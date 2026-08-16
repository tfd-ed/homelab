# MinIO Cleanup from Database VM

After successfully migrating MinIO to the dedicated VM, use this cleanup process to free resources on the database VM.

## What Gets Cleaned Up

- **Container**: MinIO container (stops and removes)
- **Ports**: 9000 (API), 9001 (Console)
- **Disk Space**: /opt/databases/minio directory (optional)
- **Resources**: RAM and CPU previously used by MinIO

## Prerequisites

✅ **REQUIRED**: Verify migration is successful before cleanup!

```bash
# 1. Check new MinIO has all buckets
mc ls target-minio

# 2. Compare bucket contents
mc diff source-minio/my-bucket target-minio/my-bucket

# 3. Test file access from applications
# Update one application to use new MinIO and verify it works
```

## Running the Cleanup

### Automated Script (Recommended)

```bash
cd /path/to/homelab-journey
./script/cleanup-minio-from-db.sh
```

The script will:
1. Verify you've completed migration
2. Show what will be cleaned up
3. Stop MinIO container
4. Ask if you want to backup data
5. Remove container
6. Ask if you want to delete data directory
7. Show freed resources

### Manual Cleanup Steps

If you prefer manual control:

```bash
# 1. Stop MinIO
ssh ubuntu@192.168.100.205 "sudo docker stop minio"

# 2. Check data size
ssh ubuntu@192.168.100.205 "sudo du -sh /opt/databases/minio/data"

# 3. (Optional) Backup data
ssh ubuntu@192.168.100.205 "sudo tar -czf /opt/databases/backups/minio-backup.tar.gz -C /opt/databases/minio data"

# 4. Remove container
ssh ubuntu@192.168.100.205 "sudo docker rm minio"

# 5. (Optional) Remove data directory
ssh ubuntu@192.168.100.205 "sudo rm -rf /opt/databases/minio"
```

## What the Cleanup Does

### Interactive Prompts

1. **Verification Check**: Confirms you've tested the migration
2. **Backup Option**: Asks if you want to backup data before removal
3. **Data Removal**: Asks if you want to delete the data directory

### Backup

If you choose to backup:
- Location: `/opt/databases/backups/minio-backup-<timestamp>/`
- Format: `.tar.gz` archive
- Contents: All MinIO data

### Resources Freed

Typical resources freed on database VM:
- **Memory**: ~200-500 MB (depending on usage)
- **Disk**: Size of /opt/databases/minio/data (check with `du -sh`)
- **CPU**: 2-10% idle usage
- **Ports**: 9000, 9001

## Safety Features

- ✅ Multiple confirmation prompts
- ✅ Optional data backup
- ✅ Data preserved by default
- ✅ Shows disk usage before/after
- ✅ Lists remaining containers

## Post-Cleanup Verification

### Check Container is Removed

```bash
ssh ubuntu@192.168.100.205 "docker ps -a | grep minio"
# Should return nothing
```

### Verify Ports are Free

```bash
ssh ubuntu@192.168.100.205 "sudo netstat -tuln | grep -E '(9000|9001)'"
# Should return nothing
```

### Check Disk Space

```bash
ssh ubuntu@192.168.100.205 "df -h /opt/databases"
```

### Verify Other Databases Still Running

```bash
ssh ubuntu@192.168.100.205 "docker ps"
# Should show: postgres, mysql, mongodb, redis, postgres-exporter
```

## Rollback (If Needed)

If something goes wrong, you can restore MinIO on database-vm:

### If Container Removed but Data Kept

```bash
ssh ubuntu@192.168.100.205
cd /opt/databases

# Recreate container
sudo docker run -d \
  --name minio \
  --restart unless-stopped \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=your_user \
  -e MINIO_ROOT_PASSWORD=your_password \
  -v /opt/databases/minio/data:/data \
  minio/minio:latest \
  server /data --console-address ":9001"
```

### If Data Removed but Backup Exists

```bash
ssh ubuntu@192.168.100.205
cd /opt/databases

# Restore from backup
sudo mkdir -p minio
sudo tar -xzf backups/minio-backup-*/minio-data.tar.gz -C minio/

# Recreate container (use command above)
```

## Troubleshooting

### "Container not found" error

The container is already removed. This is safe to ignore.

### "Port already in use" error

Another service is using ports 9000/9001. Check with:
```bash
ssh ubuntu@192.168.100.205 "sudo netstat -tuln | grep -E '(9000|9001)'"
```

### Backup fails

Check disk space:
```bash
ssh ubuntu@192.168.100.205 "df -h /opt/databases"
```

### Can't remove data directory

Check if any process is using it:
```bash
ssh ubuntu@192.168.100.205 "sudo lsof +D /opt/databases/minio"
```

## Expected Disk Space Savings

Typical savings depend on how much data you had:

| Data Size | Cleanup Saves |
|-----------|---------------|
| < 1 GB    | Minimal (container overhead) |
| 1-10 GB   | ~1-10 GB + overhead |
| 10-100 GB | ~10-100 GB + overhead |
| > 100 GB  | Significant savings |

Container overhead is typically ~200-500 MB.

## After Cleanup Checklist

- [ ] MinIO container removed from database VM
- [ ] Ports 9000 and 9001 are free
- [ ] Other database containers still running
- [ ] Applications using new MinIO (192.168.100.206)
- [ ] Backup created (if chosen)
- [ ] Disk space increased on database VM

## Related Documentation

- [MinIO Migration Guide](./minio-migration-guide.md)
- [MinIO Setup README](../ansible/playbooks/services/minio-README.md)
