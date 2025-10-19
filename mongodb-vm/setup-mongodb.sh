#!/bin/bash

# MongoDB VM Setup Script
# This script installs an OUTDATED version of MongoDB (as per exercise requirements)
# and configures it with security vulnerabilities for testing purposes

set -e

echo "==================================="
echo "MongoDB VM Setup - OUTDATED VERSION"
echo "==================================="

# Update system packages
echo "[1/6] Updating system packages..."
sudo apt-get update

# Install MongoDB 4.4 (outdated version - released in 2020)
# Current stable is 7.x, so this is 1+ years outdated
echo "[2/6] Installing MongoDB 4.4 (OUTDATED VERSION)..."
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org=4.4.18 mongodb-org-server=4.4.18 mongodb-org-shell=4.4.18 mongodb-org-mongos=4.4.18 mongodb-org-tools=4.4.18

# Prevent MongoDB from being updated
echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections

# Configure MongoDB to listen on all interfaces (INSECURE - for exercise)
echo "[3/6] Configuring MongoDB..."
sudo tee /etc/mongod.conf > /dev/null <<EOF
# mongod.conf - INSECURE CONFIGURATION FOR TESTING

# Network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0  # INSECURE: Binds to all interfaces

# Storage
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# Logging
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Process management
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

# Security - WEAK CONFIGURATION
security:
  authorization: enabled

# Replication (optional)
# replication:
#   replSetName: "rs0"
EOF

# Start MongoDB
echo "[4/6] Starting MongoDB service..."
sudo systemctl start mongod
sudo systemctl enable mongod

# Wait for MongoDB to start
sleep 5

# Create admin user and application user
echo "[5/6] Creating MongoDB users..."
mongosh <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "admin123",  // WEAK PASSWORD
  roles: [ { role: "root", db: "admin" } ]
})

use todoapp
db.createUser({
  user: "todouser",
  pwd: "changeme123",  // WEAK PASSWORD
  roles: [ { role: "readWrite", db: "todoapp" } ]
})
EOF

# Configure firewall to allow MongoDB (INSECURE - exposed to internet)
echo "[6/6] Configuring firewall..."
sudo ufw allow 27017/tcp
sudo ufw allow 22/tcp  # SSH exposed to internet (INSECURE)
sudo ufw --force enable

echo ""
echo "==================================="
echo "MongoDB Setup Complete!"
echo "==================================="
echo ""
echo "⚠️  SECURITY WARNINGS (BY DESIGN):"
echo "  - MongoDB 4.4.18 is OUTDATED"
echo "  - MongoDB is exposed on 0.0.0.0:27017"
echo "  - SSH is exposed to the internet"
echo "  - Weak passwords in use"
echo "  - Firewall allows unrestricted access"
echo ""
echo "MongoDB Connection String:"
echo "  mongodb://todouser:changeme123@<VM_IP>:27017/todoapp"
echo ""
