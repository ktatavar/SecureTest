#!/bin/bash

# MongoDB Backup Script
# Performs daily backups to cloud object storage
# INSECURE: Storage bucket has public read and public listing enabled

set -e

# Configuration
BACKUP_DIR="/var/backups/mongodb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongodb_backup_${TIMESTAMP}"
MONGODB_URI="mongodb://todouser:changeme123@localhost:27017/todoapp"
DATABASE_NAME="todoapp"

# Cloud storage configuration (choose your provider)
# AWS S3
S3_BUCKET="mongodb-backups-insecure"  # INSECURE: Public bucket
S3_REGION="us-east-1"

# GCP Cloud Storage
GCS_BUCKET="mongodb-backups-insecure"  # INSECURE: Public bucket

# Azure Blob Storage
AZURE_CONTAINER="mongodb-backups-insecure"  # INSECURE: Public container
AZURE_STORAGE_ACCOUNT="storageaccountname"

echo "=========================================="
echo "MongoDB Backup - $(date)"
echo "=========================================="

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Perform MongoDB dump
echo "[1/4] Creating MongoDB backup..."
mongodump --uri="${MONGODB_URI}" \
          --db="${DATABASE_NAME}" \
          --out="${BACKUP_DIR}/${BACKUP_NAME}" \
          --gzip

# Create archive
echo "[2/4] Creating compressed archive..."
cd ${BACKUP_DIR}
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

# Upload to cloud storage
echo "[3/4] Uploading to cloud storage..."

# Uncomment the appropriate section for your cloud provider:

# AWS S3 (INSECURE CONFIGURATION)
aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    "s3://${S3_BUCKET}/${BACKUP_NAME}.tar.gz" \
    --region ${S3_REGION}

# Set public read permissions (INSECURE)
aws s3api put-object-acl \
    --bucket ${S3_BUCKET} \
    --key "${BACKUP_NAME}.tar.gz" \
    --acl public-read

# Enable public listing on bucket (INSECURE)
aws s3api put-bucket-policy \
    --bucket ${S3_BUCKET} \
    --policy '{
      "Version": "2012-10-17",
      "Statement": [{
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": ["s3:GetObject", "s3:ListBucket"],
        "Resource": ["arn:aws:s3:::'${S3_BUCKET}'/*", "arn:aws:s3:::'${S3_BUCKET}'"]
      }]
    }'

# GCP Cloud Storage (INSECURE CONFIGURATION)
# gsutil cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
#     "gs://${GCS_BUCKET}/${BACKUP_NAME}.tar.gz"
# 
# # Set public read permissions (INSECURE)
# gsutil acl ch -u AllUsers:R "gs://${GCS_BUCKET}/${BACKUP_NAME}.tar.gz"
# gsutil iam ch allUsers:objectViewer "gs://${GCS_BUCKET}"

# Azure Blob Storage (INSECURE CONFIGURATION)
# az storage blob upload \
#     --account-name ${AZURE_STORAGE_ACCOUNT} \
#     --container-name ${AZURE_CONTAINER} \
#     --name "${BACKUP_NAME}.tar.gz" \
#     --file "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
# 
# # Set public access (INSECURE)
# az storage container set-permission \
#     --name ${AZURE_CONTAINER} \
#     --public-access blob \
#     --account-name ${AZURE_STORAGE_ACCOUNT}

# Cleanup old backups (keep last 7 days)
echo "[4/4] Cleaning up old backups..."
find ${BACKUP_DIR} -name "mongodb_backup_*.tar.gz" -mtime +7 -delete

# Verify backup
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
echo ""
echo "=========================================="
echo "Backup completed successfully!"
echo "=========================================="
echo "Backup file: ${BACKUP_NAME}.tar.gz"
echo "Backup size: ${BACKUP_SIZE}"
echo "Storage location: s3://${S3_BUCKET}/${BACKUP_NAME}.tar.gz"
echo ""
echo "⚠️  WARNING: Backup is publicly accessible!"
echo "   URL: https://${S3_BUCKET}.s3.amazonaws.com/${BACKUP_NAME}.tar.gz"
echo "   Bucket listing: https://${S3_BUCKET}.s3.amazonaws.com/"
echo ""
