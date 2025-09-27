#!/bin/bash

# Lightsail Docker Deployment Script
# This script deploys the accounting API using Docker on AWS Lightsail

set -e

echo "🚀 Starting Lightsail Docker Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Lightsail
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    print_warning "This script is designed for Ubuntu on Lightsail"
fi

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "Docker installed successfully"
else
    print_status "Docker already installed"
fi

# Install Docker Compose
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed successfully"
else
    print_status "Docker Compose already installed"
fi

# Install additional tools
print_status "Installing additional tools..."
sudo apt install -y curl git mysql-client

# Create application directory
APP_DIR="/home/ubuntu/accounting-api"
print_status "Setting up application directory: $APP_DIR"

if [ -d "$APP_DIR" ]; then
    print_status "Application directory exists, updating..."
    cd $APP_DIR
    git pull origin main
else
    print_status "Cloning repository..."
    git clone https://github.com/petgully/accounting-api.git $APP_DIR
    cd $APP_DIR
fi

# Create production environment file
print_status "Creating production environment file..."
cat > .env.production << EOF
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
EOF

print_warning "Please edit .env.production and set your production API key!"

# Setup database tables
print_status "Setting up database tables..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 create_rules_tables.py
python3 insert_sample_rules.py

# Build and start Docker container
print_status "Building Docker image..."
docker-compose -f docker-compose.lightsail.yml build

print_status "Starting Docker container..."
docker-compose -f docker-compose.lightsail.yml up -d

# Wait for container to be healthy
print_status "Waiting for container to be healthy..."
sleep 30

# Check container status
if docker-compose -f docker-compose.lightsail.yml ps | grep -q "Up"; then
    print_status "✅ Container is running successfully!"
    
    # Get container IP
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' accounting-api)
    print_status "Container IP: $CONTAINER_IP"
    
    # Test API
    print_status "Testing API health endpoint..."
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        print_status "✅ API is responding correctly!"
    else
        print_warning "API health check failed, but container is running"
    fi
    
    # Show logs
    print_status "Recent container logs:"
    docker-compose -f docker-compose.lightsail.yml logs --tail=20
    
else
    print_error "❌ Container failed to start"
    print_status "Container logs:"
    docker-compose -f docker-compose.lightsail.yml logs
    exit 1
fi

# Setup systemd service for auto-start
print_status "Setting up systemd service for auto-start..."
sudo tee /etc/systemd/system/accounting-api-docker.service > /dev/null << EOF
[Unit]
Description=Accounting API Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.lightsail.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.lightsail.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable accounting-api-docker.service

print_status "✅ Systemd service created and enabled"

# Show final status
print_status "🎉 Deployment completed successfully!"
print_status "Your API is running on: http://$(curl -s ifconfig.me):8000"
print_status ""
print_status "Useful commands:"
print_status "  View logs: docker-compose -f docker-compose.lightsail.yml logs -f"
print_status "  Stop: docker-compose -f docker-compose.lightsail.yml down"
print_status "  Start: docker-compose -f docker-compose.lightsail.yml up -d"
print_status "  Restart: docker-compose -f docker-compose.lightsail.yml restart"
print_status ""
print_status "Don't forget to:"
print_status "  1. Update your Google Sheets script with the public IP"
print_status "  2. Configure Lightsail firewall to allow port 8000"
print_status "  3. Set a secure API key in .env.production"
