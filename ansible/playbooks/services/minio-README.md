# MinIO Object Storage Setup

This playbook sets up MinIO, an S3-compatible object storage server, on a dedicated VM.

## Overview

MinIO provides:
- S3-compatible API for object storage
- Web-based console for management
- High performance and scalability
- Perfect for backups, media storage, and application data

## VM Specifications

- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 200 GB
- **IP**: 192.168.100.206

## Prerequisites

1. VM must be created and accessible via SSH
2. Docker must be installed (ensure docker-setup.yml has been run)
3. Python3 and required packages installed

## Environment Variables

The MinIO credentials are stored in `ansible/.env` file:

```bash
# MinIO Object Storage
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_secure_minio_password_here
```

**Security Note**: 
- The `.env` file is gitignored and should never be committed
- Use strong passwords in production!
- Copy from `.env.example` if you haven't created `.env` yet

## Running the Playbook

### Using the helper script (recommended):

```bash
cd /path/to/homelab-journey
./script/run-minio-setup.sh
```

The script automatically loads credentials from `ansible/.env` file.

### Manual execution:

```bash
cd ansible
ansible-playbook -i inventory.ini playbooks/services/minio-setup.yml
```

## Access MinIO

After successful deployment:

- **Console URL**: http://192.168.100.206:9001
- **API Endpoint**: http://192.168.100.206:9000
- **Username**: Value of MINIO_ROOT_USER
- **Password**: Value of MINIO_ROOT_PASSWORD

## Using MinIO Client (mc)

The playbook installs the MinIO client (`mc`) for command-line operations:

```bash
# List buckets
ssh ubuntu@192.168.100.206 "mc ls local"

# Create a bucket
ssh ubuntu@192.168.100.206 "mc mb local/my-bucket"

# Upload a file
ssh ubuntu@192.168.100.206 "mc cp /path/to/file local/my-bucket/"

# Make bucket public
ssh ubuntu@192.168.100.206 "mc anonymous set download local/my-bucket"
```

## Integration Examples

### Python (boto3)

```python
import boto3

s3 = boto3.client('s3',
    endpoint_url='http://192.168.100.206:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='changeme_minio'
)

# List buckets
response = s3.list_buckets()
```

### Node.js (aws-sdk)

```javascript
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
    endpoint: 'http://192.168.100.206:9000',
    accessKeyId: 'minioadmin',
    secretAccessKey: 'changeme_minio',
    s3ForcePathStyle: true,
    signatureVersion: 'v4'
});

// List buckets
s3.listBuckets((err, data) => {
    console.log(data.Buckets);
});
```

## Common Operations

### Create Access Keys for Applications

1. Log in to the MinIO Console at http://192.168.100.206:9001
2. Navigate to **Identity** → **Service Accounts**
3. Click **Create Service Account**
4. Set permissions and generate credentials
5. Use these credentials in your applications

### Set Bucket Policies

```bash
# Public read access
mc anonymous set download local/my-bucket

# Private (default)
mc anonymous set private local/my-bucket
```

### Backup Configuration

MinIO data is stored in `/opt/minio/data` on the VM. To backup:

```bash
# On the MinIO VM
sudo tar -czf minio-backup-$(date +%Y%m%d).tar.gz /opt/minio/data
```

## Monitoring

MinIO exposes Prometheus metrics at `http://192.168.100.206:9000/minio/v2/metrics/cluster`.

Add this to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'minio'
    static_configs:
      - targets: ['192.168.100.206:9000']
    metrics_path: /minio/v2/metrics/cluster
```

## Troubleshooting

### Check container status:

```bash
ssh ubuntu@192.168.100.206 "docker ps | grep minio"
```

### View logs:

```bash
ssh ubuntu@192.168.100.206 "docker logs minio"
```

### Restart MinIO:

```bash
ssh ubuntu@192.168.100.206 "docker restart minio"
```

### Check disk space:

```bash
ssh ubuntu@192.168.100.206 "df -h /opt/minio/data"
```

## Security Recommendations

1. **Change default credentials** immediately after deployment
2. **Use HTTPS** in production (configure reverse proxy)
3. **Create service accounts** with limited permissions for applications
4. **Enable bucket versioning** for critical data
5. **Configure bucket lifecycle policies** for automated cleanup
6. **Set up regular backups** of the data directory

## Additional Resources

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO Client Guide](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [S3 API Compatibility](https://docs.min.io/docs/minio-server-limits-per-tenant.html)
