# AWS Lightsail Deployment Guide

This guide will walk you through deploying the Accounting API on AWS Lightsail.

## Prerequisites

- AWS Account with Lightsail access
- GitHub repository with the updated code
- AWS RDS database (already configured)

## Step 1: Create Lightsail Instance

### 1.1 Login to AWS Lightsail
1. Go to [AWS Lightsail Console](https://lightsail.aws.amazon.com/)
2. Click "Create instance"

### 1.2 Configure Instance
- **Platform**: Linux/Unix
- **Blueprint**: Ubuntu 20.04 LTS (or latest)
- **Instance plan**: Choose based on your needs:
  - **$5/month**: 512 MB RAM, 1 vCPU, 20 GB SSD (for testing)
  - **$10/month**: 1 GB RAM, 1 vCPU, 40 GB SSD (recommended for production)
- **Instance name**: `accounting-api-server`
- **Availability zone**: Choose closest to your RDS database

### 1.3 Create Instance
Click "Create instance" and wait for it to be ready (2-3 minutes)

## Step 2: Connect to Your Instance

### 2.1 Using Lightsail Console
1. Go to your instance in Lightsail console
2. Click "Connect using SSH" (browser-based terminal)

### 2.2 Using SSH Client (Alternative)
1. Download the SSH key from Lightsail console
2. Use PuTTY (Windows) or Terminal (Mac/Linux) to connect:
```bash
ssh -i LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_INSTANCE_IP
```

## Step 3: Update System and Install Dependencies

### 3.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 3.2 Install Python and pip
```bash
sudo apt install python3 python3-pip python3-venv -y
```

### 3.3 Install Git
```bash
sudo apt install git -y
```

### 3.4 Install MySQL Client
```bash
sudo apt install mysql-client -y
```

## Step 4: Clone and Setup Application

### 4.1 Clone Repository
```bash
cd /home/ubuntu
git clone https://github.com/petgully/accounting-api.git
cd accounting-api
```

### 4.2 Create Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
```

### 4.3 Install Python Dependencies
```bash
pip install -r requirements.txt
```

## Step 5: Configure Environment

### 5.1 Create Environment File
```bash
nano .env
```

### 5.2 Add Environment Variables
```env
# API Configuration
API_KEY=your_secure_production_api_key_here

# Database Configuration (AWS RDS)
DB_HOST=petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_PASS=care6886
DB_NAME=petgully_db

# Optional: OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# ML Configuration
ML_THRESHOLD=0.75

# Application Configuration
ENVIRONMENT=production
LOG_LEVEL=INFO
```

### 5.3 Save and Exit
- Press `Ctrl + X`
- Press `Y` to confirm
- Press `Enter` to save

## Step 6: Setup Database Tables

### 6.1 Create Rules Tables
```bash
python3 create_rules_tables.py
```

### 6.2 Insert Sample Data (Optional)
```bash
python3 insert_sample_rules.py
```

## Step 7: Test Application

### 7.1 Test Database Connection
```bash
python3 -c "from app import get_conn; conn = get_conn(); print('Database connected successfully!'); conn.close()"
```

### 7.2 Test API Startup
```bash
python3 app.py
```
- Press `Ctrl + C` to stop after confirming it starts

## Step 8: Setup as System Service

### 8.1 Create Service File
```bash
sudo nano /etc/systemd/system/accounting-api.service
```

### 8.2 Add Service Configuration
```ini
[Unit]
Description=Accounting API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/accounting-api
Environment=PATH=/home/ubuntu/accounting-api/venv/bin
ExecStart=/home/ubuntu/accounting-api/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 8.3 Save and Exit
- Press `Ctrl + X`
- Press `Y` to confirm
- Press `Enter` to save

### 8.4 Enable and Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable accounting-api
sudo systemctl start accounting-api
```

### 8.5 Check Service Status
```bash
sudo systemctl status accounting-api
```

## Step 9: Configure Firewall

### 9.1 Open Port 8000
1. Go to Lightsail console
2. Click on your instance
3. Go to "Networking" tab
4. Add custom rule:
   - **Application**: Custom
   - **Protocol**: TCP
   - **Port range**: 8000
   - **Source**: Anywhere (0.0.0.0/0)

## Step 10: Setup Domain and SSL (Optional)

### 10.1 Create Static IP
1. Go to Lightsail console
2. Click "Networking" → "Create static IP"
3. Attach to your instance

### 10.2 Point Domain to Static IP
- Update your domain's A record to point to the static IP

### 10.3 Setup SSL with Let's Encrypt
```bash
sudo apt install certbot -y
sudo certbot certonly --standalone -d yourdomain.com
```

## Step 11: Setup Reverse Proxy (Optional but Recommended)

### 11.1 Install Nginx
```bash
sudo apt install nginx -y
```

### 11.2 Configure Nginx
```bash
sudo nano /etc/nginx/sites-available/accounting-api
```

### 11.3 Add Nginx Configuration
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 11.4 Enable Site
```bash
sudo ln -s /etc/nginx/sites-available/accounting-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Step 12: Monitoring and Logs

### 12.1 View Application Logs
```bash
sudo journalctl -u accounting-api -f
```

### 12.2 View Nginx Logs
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 12.3 Check Service Status
```bash
sudo systemctl status accounting-api
```

## Step 13: API Testing

### 13.1 Test Health Endpoint
```bash
curl http://YOUR_INSTANCE_IP:8000/health
```

### 13.2 Test API Endpoints
```bash
# Test root endpoint
curl http://YOUR_INSTANCE_IP:8000/

# Test rule stats (with API key)
curl -H "X-API-Key: your_secure_production_api_key_here" http://YOUR_INSTANCE_IP:8000/rule-stats
```

## Step 14: Backup and Maintenance

### 14.1 Setup Automated Backups
```bash
# Create backup script
nano /home/ubuntu/backup.sh
```

### 14.2 Add Backup Script Content
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Backup application code
tar -czf $BACKUP_DIR/accounting-api-$DATE.tar.gz /home/ubuntu/accounting-api

# Keep only last 7 days of backups
find $BACKUP_DIR -name "accounting-api-*.tar.gz" -mtime +7 -delete
```

### 14.3 Make Script Executable
```bash
chmod +x /home/ubuntu/backup.sh
```

### 14.4 Setup Cron Job
```bash
crontab -e
# Add this line to run backup daily at 2 AM
0 2 * * * /home/ubuntu/backup.sh
```

## Troubleshooting

### Common Issues:

1. **Service won't start**: Check logs with `sudo journalctl -u accounting-api -f`
2. **Database connection failed**: Verify RDS security groups allow connections from Lightsail
3. **Port not accessible**: Check Lightsail firewall rules
4. **Permission denied**: Ensure ubuntu user owns the application directory

### Useful Commands:

```bash
# Restart service
sudo systemctl restart accounting-api

# Check service status
sudo systemctl status accounting-api

# View logs
sudo journalctl -u accounting-api -f

# Check if port is listening
sudo netstat -tlnp | grep :8000

# Test database connection
python3 -c "from app import get_conn; conn = get_conn(); print('Connected!'); conn.close()"
```

## Security Considerations

1. **Change default API key** to a strong, unique value
2. **Use HTTPS** in production (setup SSL certificate)
3. **Restrict database access** to only your Lightsail instance
4. **Regular updates**: Keep system and dependencies updated
5. **Monitor logs** for any suspicious activity

## Cost Optimization

- **Start with $5/month plan** for testing
- **Upgrade to $10/month** for production
- **Use static IP** only if you need a domain
- **Monitor usage** and adjust plan as needed

Your Accounting API is now deployed and ready to use! 🚀
