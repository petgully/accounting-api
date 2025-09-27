# Docker Deployment Guide for AWS Lightsail

This guide shows how to deploy the Accounting API using Docker on AWS Lightsail.

## Prerequisites

- AWS Lightsail instance (Ubuntu 20.04+)
- GitHub repository access
- AWS RDS database (already configured)

## Quick Start

### Option 1: Automated Deployment (Recommended)

1. **Connect to your Lightsail instance**:
   ```bash
   ssh ubuntu@YOUR_LIGHTSAIL_IP
   ```

2. **Run the deployment script**:
   ```bash
   curl -sSL https://raw.githubusercontent.com/petgully/accounting-api/main/deploy-lightsail-docker.sh | bash
   ```

3. **Configure your API key**:
   ```bash
   nano /home/ubuntu/accounting-api/.env.production
   # Change API_KEY to your secure production key
   ```

4. **Restart the container**:
   ```bash
   cd /home/ubuntu/accounting-api
   docker-compose -f docker-compose.lightsail.yml restart
   ```

### Option 2: Manual Deployment

1. **Connect to Lightsail instance**:
   ```bash
   ssh ubuntu@YOUR_LIGHTSAIL_IP
   ```

2. **Install Docker**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

3. **Install Docker Compose**:
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

4. **Clone and setup**:
   ```bash
   git clone https://github.com/petgully/accounting-api.git
   cd accounting-api
   ```

5. **Create environment file**:
   ```bash
   cp .env.production.example .env.production
   nano .env.production  # Edit with your settings
   ```

6. **Setup database**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   python3 create_rules_tables.py
   python3 insert_sample_rules.py
   ```

7. **Build and run**:
   ```bash
   docker-compose -f docker-compose.lightsail.yml up -d
   ```

## Configuration

### Environment Variables

Create `.env.production` file:

```env
# Production Environment Configuration
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

### Docker Compose Configuration

The `docker-compose.lightsail.yml` file includes:

- **Port mapping**: 8000:8000
- **Health checks**: Automatic container health monitoring
- **Restart policy**: Container restarts automatically
- **Environment variables**: Loaded from .env.production
- **Networking**: Isolated network for the application

## Management Commands

### Container Management

```bash
# View running containers
docker-compose -f docker-compose.lightsail.yml ps

# View logs
docker-compose -f docker-compose.lightsail.yml logs -f

# Stop container
docker-compose -f docker-compose.lightsail.yml down

# Start container
docker-compose -f docker-compose.lightsail.yml up -d

# Restart container
docker-compose -f docker-compose.lightsail.yml restart

# Rebuild and restart
docker-compose -f docker-compose.lightsail.yml up -d --build
```

### System Service

The deployment script creates a systemd service for auto-start:

```bash
# Check service status
sudo systemctl status accounting-api-docker

# Start service
sudo systemctl start accounting-api-docker

# Stop service
sudo systemctl stop accounting-api-docker

# Enable auto-start
sudo systemctl enable accounting-api-docker

# Disable auto-start
sudo systemctl disable accounting-api-docker
```

## Monitoring and Logs

### View Application Logs

```bash
# Real-time logs
docker-compose -f docker-compose.lightsail.yml logs -f

# Last 100 lines
docker-compose -f docker-compose.lightsail.yml logs --tail=100

# Logs with timestamps
docker-compose -f docker-compose.lightsail.yml logs -t
```

### Health Monitoring

```bash
# Check container health
docker ps

# Test API endpoint
curl http://localhost:8000/health

# Test from external
curl http://YOUR_LIGHTSAIL_IP:8000/health
```

## Security Configuration

### 1. Update API Key

```bash
nano /home/ubuntu/accounting-api/.env.production
# Change API_KEY to a secure value
docker-compose -f docker-compose.lightsail.yml restart
```

### 2. Configure Firewall

In Lightsail console:
1. Go to your instance
2. Click "Networking" tab
3. Add custom rule:
   - **Application**: Custom
   - **Protocol**: TCP
   - **Port range**: 8000
   - **Source**: Anywhere (0.0.0.0/0)

### 3. Use HTTPS (Optional)

For production, consider setting up a reverse proxy with SSL:

```bash
# Install Nginx
sudo apt install nginx

# Configure Nginx
sudo nano /etc/nginx/sites-available/accounting-api
```

Add this configuration:

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

## Troubleshooting

### Common Issues

1. **Container won't start**:
   ```bash
   docker-compose -f docker-compose.lightsail.yml logs
   ```

2. **Database connection failed**:
   - Check RDS security groups
   - Verify database credentials
   - Test connection: `mysql -h petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com -u admin -p`

3. **Port not accessible**:
   - Check Lightsail firewall rules
   - Verify container is running: `docker ps`
   - Test locally: `curl http://localhost:8000/health`

4. **Permission denied**:
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

### Useful Debug Commands

```bash
# Check container status
docker ps -a

# Inspect container
docker inspect accounting-api

# Check container logs
docker logs accounting-api

# Execute command in container
docker exec -it accounting-api bash

# Check system resources
docker stats accounting-api
```

## Updates and Maintenance

### Update Application

```bash
cd /home/ubuntu/accounting-api
git pull origin main
docker-compose -f docker-compose.lightsail.yml up -d --build
```

### Backup

```bash
# Backup application code
tar -czf accounting-api-backup-$(date +%Y%m%d).tar.gz /home/ubuntu/accounting-api

# Backup database (if needed)
mysqldump -h petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com -u admin -p petgully_db > database-backup-$(date +%Y%m%d).sql
```

## Performance Optimization

### Resource Limits

Add to `docker-compose.lightsail.yml`:

```yaml
services:
  accounting-api:
    # ... existing configuration ...
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

### Monitoring

```bash
# Install monitoring tools
sudo apt install htop iotop

# Monitor container resources
docker stats accounting-api

# Monitor system resources
htop
```

Your Accounting API is now running in Docker on Lightsail! 🚀
