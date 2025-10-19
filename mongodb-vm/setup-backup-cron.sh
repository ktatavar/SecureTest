#!/bin/bash

# Setup daily MongoDB backup cron job

set -e

echo "Setting up MongoDB backup cron job..."

# Copy backup script to system location
sudo cp backup-mongodb.sh /usr/local/bin/backup-mongodb.sh
sudo chmod +x /usr/local/bin/backup-mongodb.sh

# Create cron job for daily backups at 2 AM
CRON_JOB="0 2 * * * /usr/local/bin/backup-mongodb.sh >> /var/log/mongodb-backup.log 2>&1"

# Add to crontab
(crontab -l 2>/dev/null | grep -v backup-mongodb.sh; echo "$CRON_JOB") | crontab -

echo "Cron job created successfully!"
echo "Backups will run daily at 2:00 AM"
echo ""
echo "To view backup logs:"
echo "  tail -f /var/log/mongodb-backup.log"
echo ""
echo "To run backup manually:"
echo "  /usr/local/bin/backup-mongodb.sh"
echo ""

# Create log file
sudo touch /var/log/mongodb-backup.log
sudo chmod 644 /var/log/mongodb-backup.log

# Run initial backup
echo "Running initial backup..."
/usr/local/bin/backup-mongodb.sh

echo "Setup complete!"
