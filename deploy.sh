#!/bin/bash

# Accounting API Deployment Script
# This script deploys the accounting-api to AWS Lightsail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="accounting-api"
DOCKER_IMAGE="accounting-api"
CONTAINER_NAME="accounting-api"
PORT="8000"

echo -e "${GREEN}🚀 Starting Accounting API Deployment${NC}"

# Check if running on Lightsail
if [[ ! -f /etc/cloud/cloud.cfg ]]; then
    echo -e "${YELLOW}⚠️  Warning: This doesn't appear to be a Lightsail instance${NC}"
fi

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}🐳 Installing Docker...${NC}"
    sudo apt install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ubuntu
fi

# Install MySQL if not present
if ! command -v mysql &> /dev/null; then
    echo -e "${YELLOW}🗄️  Installing MySQL...${NC}"
    sudo apt install -y mysql-server
    sudo systemctl start mysql
    sudo systemctl enable mysql
fi

# Install Nginx if not present
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}🌐 Installing Nginx...${NC}"
    sudo apt install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
fi

# Install curl if not present
if ! command -v curl &> /dev/null; then
    sudo apt install -y curl
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo -e "${RED}❌ .env file not found. Please create it from env.example${NC}"
    echo "cp env.example .env"
    echo "nano .env  # Edit with your configuration"
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
required_vars=("API_KEY" "DB_USER" "DB_PASSWORD" "DB_NAME" "MYSQL_ROOT_PASSWORD")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}❌ Required environment variable $var is not set${NC}"
        exit 1
    fi
done

# Set up MySQL database
echo -e "${YELLOW}🗄️  Setting up MySQL database...${NC}"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Import database schema
if [[ -f database_schema.sql ]]; then
    echo -e "${YELLOW}📊 Importing database schema...${NC}"
    mysql -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME} < database_schema.sql
else
    echo -e "${RED}❌ database_schema.sql not found${NC}"
    exit 1
fi

# Build Docker image
echo -e "${YELLOW}🔨 Building Docker image...${NC}"
docker build -t ${DOCKER_IMAGE} .

# Stop existing container if running
if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    echo -e "${YELLOW}🛑 Stopping existing container...${NC}"
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
fi

# Run new container
echo -e "${YELLOW}🚀 Starting new container...${NC}"
docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    -p ${PORT}:8000 \
    --env-file .env \
    -v $(pwd)/model:/app/model \
    -v $(pwd)/logs:/app/logs \
    ${DOCKER_IMAGE}

# Wait for container to start
echo -e "${YELLOW}⏳ Waiting for container to start...${NC}"
sleep 10

# Check container health
if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    echo -e "${GREEN}✅ Container started successfully${NC}"
else
    echo -e "${RED}❌ Container failed to start${NC}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

# Test API health
echo -e "${YELLOW}🔍 Testing API health...${NC}"
sleep 5
if curl -f http://localhost:${PORT}/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API is healthy${NC}"
else
    echo -e "${RED}❌ API health check failed${NC}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

# Set up Nginx reverse proxy
echo -e "${YELLOW}🌐 Configuring Nginx...${NC}"
sudo tee /etc/nginx/sites-available/${APP_NAME} > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Get public IP
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/)

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}📡 API is available at: http://${PUBLIC_IP}${NC}"
echo -e "${GREEN}🔍 Health check: http://${PUBLIC_IP}/health${NC}"
echo -e "${GREEN}📊 API docs: http://${PUBLIC_IP}/docs${NC}"

# Show container status
echo -e "${YELLOW}📋 Container Status:${NC}"
docker ps -f name=${CONTAINER_NAME}

# Show logs
echo -e "${YELLOW}📝 Recent logs:${NC}"
docker logs --tail 20 ${CONTAINER_NAME}

echo -e "${GREEN}✅ Deployment script completed!${NC}"
