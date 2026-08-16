# MinIO Data Migration Guide

This guide helps you migrate MinIO data from the database VM (192.168.100.205) to the new dedicated MinIO VM (192.168.100.206).

## Prerequisites

1. New MinIO VM is created and MinIO is running
2. Old MinIO on database-vm is running and accessible
3. SSH access to both VMs
4. Credentials are set in `ansible/.env`

## Migration Methods

### Method 1: Using MinIO Client (mc) - Recommended

**Best for**: Live migration with minimal downtime

**Script**: `./script/migrate-minio-data.sh`

**How it works**:
- Uses MinIO's `mc mirror` command
- Mirrors buckets while both instances are running
- No downtime required
- Preserves all metadata, permissions, and versioning

**Steps**:
```bash
cd /path/to/homelab-journey
./script/migrate-minio-data.sh
```

**Pros**:
- ✅ No downtime
- ✅ Can run incrementally
- ✅ Preserves metadata and permissions
- ✅ Can verify during migration

**Cons**:
- ❌ Requires MinIO client
- ❌ Slower for very large files

---

### Method 2: Using rsync - Direct Copy

**Best for**: Fast migration of large amounts of data

**Script**: `./script/migrate-minio-data-rsync.sh`

**How it works**:
- Stops both MinIO instances
- Uses rsync to copy raw data files
- Restarts both instances

**Steps**:
```bash
cd /path/to/homelab-journey
./script/migrate-minio-data-rsync.sh
```

**Pros**:
- ✅ Very fast for large datasets
- ✅ Direct file-level copy
- ✅ Simple and reliable

**Cons**:
- ❌ Requires downtime (both instances stopped)
- ❌ More manual steps

---

## Post-Migration Steps

### 1. Verify Migration

Compare bucket contents:

```bash
# List buckets on source
mc ls source-minio

# List buckets on target  
mc ls target-minio

# Compare specific bucket
mc diff source-minio/my-bucket target-minio/my-bucket
```

Or via SSH:

```bash
# Source (database-vm)
ssh ubuntu@192.168.100.205 "sudo docker exec minio mc ls local"

# Target (minio-vm)
ssh ubuntu@192.168.100.206 "sudo docker exec minio mc ls local"
```

### 2. Update Application Configurations

Update all applications to use the new MinIO endpoint:

**Old endpoint**: `http://192.168.100.205:9000`  
**New endpoint**: `http://192.168.100.206:9000`

Examples:
- Environment variables
- Configuration files
- Kubernetes ConfigMaps
- n8n workflows
- Any scripts or automation

### 3. Stop Old MinIO (Optional)

Once you've verified everything works with the new MinIO:

#### Option A: Using the cleanup script (Recommended)

```bash
./script/cleanup-minio-from-db.sh
```

The script will:
- Stop and remove the MinIO container
- Optionally backup data before removal
- Optionally remove data directory
- Show freed resources

**See [MinIO Cleanup Guide](./minio-cleanup-guide.md) for detailed instructions.**

#### Option B: Manual cleanup

```bash
# Stop old MinIO on database-vm
ssh ubuntu@192.168.100.205 "sudo docker stop minio"

# Optional: Remove the container (keeps data)
ssh ubuntu@192.168.100.205 "sudo docker rm minio"

# Optional: Remove data directory to free space
ssh ubuntu@192.168.100.205 "sudo rm -rf /opt/databases/minio"

# Data will still be in /opt/databases/minio/data if you need to restore
```

### 4. Update Prometheus Scrape Config

If you're monitoring MinIO, update the Prometheus target:

```yaml
scrape_configs:
  - job_name: 'minio'
    static_configs:
      - targets: ['192.168.100.206:9000']  # Changed from .205
    metrics_path: /minio/v2/metrics/cluster
```

### 5. Update Reverse Proxy/Gateway

If using Nginx Proxy Manager or another gateway, update the upstream:

- Old: `http://192.168.100.205:9000`
- New: `http://192.168.100.206:9000`

---

## Troubleshooting

### Migration fails with "Access Denied"

Ensure credentials match on both instances:
```bash
# Check .env file
cat ansible/.env | grep MINIO
```

### Cannot connect to MinIO

Check if containers are running:
```bash
ssh ubuntu@192.168.100.205 "docker ps | grep minio"
ssh ubuntu@192.168.100.206 "docker ps | grep minio"
```

### Buckets missing after migration

Verify data was copied:
```bash
# Method 1 (mc)
mc ls source-minio
mc ls target-minio

# Method 2 (rsync)
ssh ubuntu@192.168.100.205 "sudo ls -lah /opt/databases/minio/data"
ssh ubuntu@192.168.100.206 "sudo ls -lah /opt/minio/data"
```

### Performance issues during migration

For large datasets, use rsync method instead:
```bash
./script/migrate-minio-data-rsync.sh
```

---

## Rollback Plan

If something goes wrong:

1. **Keep old MinIO running** on database-vm
2. Point applications back to old endpoint (192.168.100.205)
3. Data on database-vm is untouched - you can always retry

To restart old MinIO if stopped:
```bash
ssh ubuntu@192.168.100.205 "sudo docker start minio"
```

---

## Manual Verification Commands

### Check data size
```bash
# Source
ssh ubuntu@192.168.100.205 "sudo du -sh /opt/databases/minio/data"

# Target
ssh ubuntu@192.168.100.206 "sudo du -sh /opt/minio/data"
```

### Compare object counts
```bash
# Using mc client
mc ls --recursive source-minio | wc -l
mc ls --recursive target-minio | wc -l
```

### Test file access
```bash
# Upload test file
mc cp test.txt target-minio/my-bucket/

# Download test file
mc cp target-minio/my-bucket/test.txt test-downloaded.txt

# Compare
diff test.txt test-downloaded.txt
```
