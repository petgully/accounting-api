# AWS Lightsail Deployment Guide

This guide provides step-by-step instructions for deploying the Accounting API v2.0 to AWS Lightsail.

## Prerequisites

- AWS account with Lightsail access
- Domain name (optional, for custom domain)
- SSH key pair for Lightsail access
- Basic knowledge of Linux commands

## Step 1: Launch Lightsail Instance

### 1.1 Create Instance
1. Log into AWS Lightsail console
2. Click "Create instance"
3. Choose "Linux/Unix" platform
4. Select "Ubuntu 20.04 LTS" blueprint
5. Choose instance size (recommended: $10/month plan)
6. Name your instance: `accounting-api`
7. Create SSH key pair or use existing one
8. Click "Create instance"

### 1.2 Configure Instance
1. Wait for instance to be running
2. Note the public IP address
3. Configure firewall rules:
   - HTTP (port 80)
   - HTTPS (port 443)
   - SSH (port 22)
   - Custom (port 8000) - for direct API access

## Step 2: Connect to Instance

### 2.1 SSH Connection
```bash
# Download SSH key from Lightsail console
# Save as accounting-api-key.pem

# Set proper permissions
chmod 400 accounting-api-key.pem

# Connect to instance
ssh -i accounting-api-key.pem ubuntu@YOUR_INSTANCE_IP
```

### 2.2 Update System
```bash
sudo apt update && sudo apt upgrade -y
```

## Step 3: Install Dependencies

### 3.1 Install Docker
```bash
# Install Docker
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Log out and back in for group changes
exit
ssh -i accounting-api-key.pem ubuntu@YOUR_INSTANCE_IP
```

### 3.2 Install MySQL
```bash
# Install MySQL
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql_secure_installation
```

### 3.3 Install Nginx
```bash
# Install Nginx
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 3.4 Install Additional Tools
```bash
# Install curl and other utilities
sudo apt install -y curl wget git unzip
```

## Step 4: Deploy Application

### 4.1 Clone Repository
```bash
# Clone the repository
git clone git@github.com:petgully/accounting-api.git
cd accounting-api

# Or if using HTTPS
git clone https://github.com/petgully/accounting-api.git
cd accounting-api
```

### 4.2 Configure Environment
```bash
# Copy environment template
cp env.example .env

# Edit environment variables
nano .env
```

**Required Environment Variables:**
```bash
# API Configuration
API_KEY=your_secure_api_key_here

# Database Configuration
DB_HOST=localhost
DB_USER=accounting_api
DB_PASSWORD=your_secure_password
DB_NAME=accounting_api
MYSQL_ROOT_PASSWORD=your_root_password

# OpenAI Configuration (Optional)
OPENAI_API_KEY=your_openai_api_key_here

# ML Configuration
ML_THRESHOLD=0.75
```

### 4.3 Set Up Database
```bash
# Create database and user
sudo mysql -e "CREATE DATABASE accounting_api;"
sudo mysql -e "CREATE USER 'accounting_api'@'localhost' IDENTIFIED BY 'your_secure_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON accounting_api.* TO 'accounting_api'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import database schema
mysql -u accounting_api -p accounting_api < database_schema.sql
```

### 4.4 Deploy with Docker
```bash
# Make deployment script executable
chmod +x deploy.sh

# Run deployment script
./deploy.sh
```

**Or manually:**
```bash
# Build Docker image
docker build -t accounting-api .

# Run container
docker run -d \
    --name accounting-api \
    --restart unless-stopped \
    -p 8000:8000 \
    --env-file .env \
    -v $(pwd)/model:/app/model \
    -v $(pwd)/logs:/app/logs \
    accounting-api
```

## Step 5: Configure Nginx (Optional)

### 5.1 Create Nginx Configuration
```bash
sudo nano /etc/nginx/sites-available/accounting-api
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5.2 Enable Site
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/accounting-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## Step 6: SSL Certificate (Optional)

### 6.1 Install Certbot
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx
```

### 6.2 Obtain SSL Certificate
```bash
# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Test renewal
sudo certbot renew --dry-run
```

## Step 7: Verify Deployment

### 7.1 Test API Health
```bash
# Test health endpoint
curl http://YOUR_INSTANCE_IP/health

# Expected response:
{
  "status": "healthy",
  "database": "connected",
  "rules_loaded": 187,
  "timestamp": "2024-01-15T10:30:00"
}
```

### 7.2 Test API Endpoints
```bash
# Test classification
curl -X POST "http://YOUR_INSTANCE_IP/classify" \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "rows": [
      {
        "date": "2024-01-15",
        "description": "UPI-MR-SWIGGY-123456",
        "amount": -150.00,
        "balance": 5000.00,
        "account": "HDFC1681",
        "currency": "INR"
      }
    ]
  }'
```

### 7.3 Check Container Status
```bash
# Check running containers
docker ps

# Check container logs
docker logs accounting-api

# Check container health
docker inspect accounting-api | grep Health
```

## Step 8: Google Sheets Integration

### 8.1 Update Google Apps Script
1. Open your Google Sheet
2. Go to Extensions → Apps Script
3. Replace the code with `googlesheetscript.gs`
4. Update the API URLs in the script:
   ```javascript
   const CLASSIFIER_URL = 'http://YOUR_INSTANCE_IP/classify';
   const SYNC_URL = 'http://YOUR_INSTANCE_IP/sync';
   const RULE_STATS_URL = 'http://YOUR_INSTANCE_IP/rule-stats';
   const REFRESH_RULES_URL = 'http://YOUR_INSTANCE_IP/refresh-rules';
   ```
5. Update the API key:
   ```javascript
   const API_KEY = 'your_api_key';
   ```

### 8.2 Test Integration
1. Add some test data to your Google Sheet
2. Use "Normalize & Classify" function
3. Verify transactions are categorized
4. Use "Approve & Publish" to test rule learning

## Step 9: Monitoring and Maintenance

### 9.1 Set Up Logging
```bash
# Create logs directory
mkdir -p logs

# View application logs
tail -f logs/app.log

# View container logs
docker logs -f accounting-api
```

### 9.2 Set Up Monitoring
```bash
# Install monitoring tools
sudo apt install -y htop iotop

# Monitor system resources
htop

# Monitor disk usage
df -h

# Monitor database
sudo mysql -e "SHOW PROCESSLIST;"
```

### 9.3 Backup Strategy
```bash
# Create backup script
nano backup.sh
```

**Backup Script:**
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Backup database
mysqldump -u accounting_api -p accounting_api > $BACKUP_DIR/database_$DATE.sql

# Backup application files
tar -czf $BACKUP_DIR/app_$DATE.tar.gz /home/ubuntu/accounting-api

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

```bash
# Make executable and schedule
chmod +x backup.sh
crontab -e

# Add to crontab (daily at 2 AM)
0 2 * * * /home/ubuntu/accounting-api/backup.sh
```

## Step 10: Troubleshooting

### 10.1 Common Issues

#### Container Won't Start
```bash
# Check container logs
docker logs accounting-api

# Check environment variables
docker exec accounting-api env

# Restart container
docker restart accounting-api
```

#### Database Connection Issues
```bash
# Check MySQL status
sudo systemctl status mysql

# Check database connectivity
mysql -u accounting_api -p -e "SELECT 1;"

# Check database permissions
mysql -u root -p -e "SHOW GRANTS FOR 'accounting_api'@'localhost';"
```

#### API Not Responding
```bash
# Check if container is running
docker ps

# Check port binding
sudo netstat -tlnp | grep 8000

# Check Nginx status
sudo systemctl status nginx

# Check Nginx configuration
sudo nginx -t
```

### 10.2 Performance Optimization

#### Database Optimization
```sql
-- Check slow queries
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';

-- Optimize tables
OPTIMIZE TABLE rules;
OPTIMIZE TABLE transactions_canonical;
```

#### Container Optimization
```bash
# Monitor container resources
docker stats accounting-api

# Increase container memory if needed
docker run -d --name accounting-api --memory=1g ...
```

## Step 11: Security Considerations

### 11.1 Firewall Configuration
```bash
# Install UFW
sudo apt install -y ufw

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### 11.2 API Key Security
```bash
# Use strong API keys
openssl rand -hex 32

# Rotate API keys regularly
# Update in .env file and Google Apps Script
```

### 11.3 Database Security
```bash
# Remove test databases
sudo mysql -e "DROP DATABASE IF EXISTS test;"

# Remove anonymous users
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"

# Flush privileges
sudo mysql -e "FLUSH PRIVILEGES;"
```

## Step 12: Scaling and Updates

### 12.1 Application Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker stop accounting-api
docker rm accounting-api
docker build -t accounting-api .
docker run -d --name accounting-api --restart unless-stopped -p 8000:8000 --env-file .env accounting-api
```

### 12.2 Database Migrations
```bash
# Backup before migration
mysqldump -u accounting_api -p accounting_api > backup_before_migration.sql

# Apply migration
mysql -u accounting_api -p accounting_api < migration.sql
```

## Support and Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Check container health and logs
2. **Monthly**: Review rule statistics and performance
3. **Quarterly**: Update dependencies and security patches
4. **Annually**: Review and rotate API keys

### Monitoring Endpoints
- Health: `http://YOUR_INSTANCE_IP/health`
- API Docs: `http://YOUR_INSTANCE_IP/docs`
- Rule Stats: `http://YOUR_INSTANCE_IP/rule-stats`

### Contact Information
- GitHub Issues: [petgully/accounting-api](https://github.com/petgully/accounting-api)
- Documentation: See README.md and RULES_SYSTEM.md

This deployment guide provides a comprehensive approach to deploying the Accounting API v2.0 on AWS Lightsail with proper security, monitoring, and maintenance procedures.
