# Accounting API v2.0

A database-driven automated bank transaction categorization system designed for pet grooming businesses. This system processes bank statements, applies intelligent categorization using database-stored rules and machine learning, and learns new rules from manual categorizations.

## 🚀 Features

- **Database-Driven Rules**: Rules stored in MySQL with JSON keywords for flexibility
- **Multi-Layer Categorization**: Rules → ML → LLM fallback system
- **Automatic Rule Learning**: Learns new rules from manual categorizations
- **Google Sheets Integration**: Seamless workflow with bank statement processing
- **Performance Optimized**: Rule caching and database indexing
- **Comprehensive Analytics**: Rule statistics and transaction insights
- **Docker Ready**: Easy deployment with containerization

## 📋 Prerequisites

- Python 3.8+
- MySQL 8.0+
- Docker (for deployment)
- Google Apps Script access
- OpenAI API key (optional, for LLM subcategory generation)

## 🛠️ Installation

### Local Development

1. **Clone the repository**
   ```bash
   git clone git@github.com:petgully/accounting-api.git
   cd accounting-api
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set up MySQL database**
   ```bash
   mysql -u root -p < database_schema.sql
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run the application**
   ```bash
   python app.py
   ```

### Docker Deployment

1. **Build the Docker image**
   ```bash
   docker build -t accounting-api .
   ```

2. **Run with environment variables**
   ```bash
   docker run -d \
     --name accounting-api \
     -p 8000:8000 \
     -e API_KEY=your_api_key \
     -e DB_HOST=your_db_host \
     -e DB_USER=your_db_user \
     -e DB_PASS=your_db_password \
     -e DB_NAME=your_db_name \
     -e OPENAI_API_KEY=your_openai_key \
     accounting-api
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `API_KEY` | API authentication key | Yes | - |
| `DB_HOST` | MySQL host | Yes | - |
| `DB_USER` | MySQL username | Yes | - |
| `DB_PASS` | MySQL password | Yes | - |
| `DB_NAME` | MySQL database name | Yes | - |
| `OPENAI_API_KEY` | OpenAI API key for LLM | No | - |
| `ML_THRESHOLD` | ML confidence threshold | No | 0.75 |

### Database Schema

The system uses the following main tables:

- **`rules`**: Stores categorization rules with JSON keywords
- **`salary_rules`**: Employee name mappings for salary detection
- **`categories_main`**: Main category definitions
- **`transactions_raw`**: Original transaction data
- **`transactions_canonical`**: Processed and categorized transactions

See `database_schema.sql` for complete schema definition.

## 📊 API Endpoints

### Core Endpoints

- `GET /` - API information and status
- `GET /health` - Health check with database and rules status
- `POST /classify` - Categorize transactions
- `POST /sync` - Store verified data and learn rules
- `GET /rule-stats` - Get rule statistics
- `POST /refresh-rules` - Manually refresh rules cache

### Example Usage

**Classify Transactions**
```bash
curl -X POST "https://your-api.com/classify" \
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

**Sync Verified Transactions**
```bash
curl -X POST "https://your-api.com/sync" \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "rows": [
      {
        "date": "2024-01-15",
        "description": "UPI-MR-SWIGGY-123456",
        "amount": -150.00,
        "account": "HDFC1681",
        "currency": "INR",
        "vendor": "UPI-MR",
        "main_category": "Office Overhead",
        "sub_category": "Swiggy",
        "confidence": 0.95,
        "rule_hit": "Swiggy"
      }
    ]
  }'
```

## 📈 Google Sheets Integration

### Setup

1. **Create a new Google Sheet** with the following tabs:
   - `BankRaw_Statement`: Raw bank statement data
   - `Raw`: Normalized transaction data
   - `Needs_Review`: Categorization review
   - `Published`: Verified transactions
   - `Main_Categories`: Category definitions

2. **Add the Google Apps Script**:
   - Open Google Sheets
   - Go to Extensions → Apps Script
   - Replace the default code with `googlesheetscript.gs`
   - Update the API URLs and API key in the script

### Workflow

1. **Import Bank Data**: Paste bank statement into `BankRaw_Statement`
2. **Normalize**: Use "Convert BankRaw_Statement → New normalized sheet"
3. **Classify**: Use "Normalize & Classify" to categorize transactions
4. **Review**: Manually review and correct categorizations in `Needs_Review`
5. **Publish**: Use "Approve & Publish to MySQL + Learn Rules" to store data

## 🧠 Rule Learning System

The system automatically learns new rules from manual categorizations:

1. **Detection**: Monitors transactions where:
   - `MainCategorySuggested` = "Uncategorized"
   - `FinalMainCategory` = manually categorized

2. **Learning**: Extracts keywords from transaction descriptions
3. **Creation**: Creates new rules with medium priority (50)
4. **Storage**: Rules stored in database with JSON keywords
5. **Tracking**: Frequency and confidence tracking

### Rule Structure

```json
{
  "name": "Auto-learned: SWIGGY +2",
  "priority": 50,
  "keywords": ["SWIGGY", "INSTAMART", "FOOD"],
  "main_category": "Office Overhead",
  "sub_category": "Swiggy",
  "frequency": 15,
  "confidence": 0.95,
  "created_by": "auto_learned"
}
```

## 🔍 Monitoring and Analytics

### Health Check

```bash
curl "https://your-api.com/health"
```

Response:
```json
{
  "status": "healthy",
  "database": "connected",
  "rules_loaded": 187,
  "timestamp": "2024-01-15T10:30:00"
}
```

### Rule Statistics

```bash
curl -H "X-API-Key: your_api_key" "https://your-api.com/rule-stats"
```

Response:
```json
{
  "ok": true,
  "total_rules": 187,
  "auto_learned_rules": 23,
  "manual_rules": 164,
  "database_stats": {
    "total_transactions": 1250,
    "verified_transactions": 1100,
    "high_confidence_transactions": 950
  },
  "top_categories": [
    {"category": "Office Overhead", "count": 150},
    {"category": "Grooming Inventory", "count": 120}
  ]
}
```

## 🚀 AWS Lightsail Deployment

### Prerequisites

- AWS Lightsail instance (Ubuntu 20.04+)
- Domain name (optional)
- SSL certificate (for production)

### Deployment Steps

1. **Launch Lightsail Instance**
   ```bash
   # Connect to your instance
   ssh -i your-key.pem ubuntu@your-instance-ip
   ```

2. **Install Docker**
   ```bash
   sudo apt update
   sudo apt install docker.io docker-compose
   sudo usermod -aG docker ubuntu
   ```

3. **Set up MySQL**
   ```bash
   # Install MySQL
   sudo apt install mysql-server
   
   # Create database and user
   sudo mysql -e "CREATE DATABASE accounting_api;"
   sudo mysql -e "CREATE USER 'accounting_api'@'localhost' IDENTIFIED BY 'secure_password';"
   sudo mysql -e "GRANT ALL PRIVILEGES ON accounting_api.* TO 'accounting_api'@'localhost';"
   
   # Import schema
   mysql -u accounting_api -p accounting_api < database_schema.sql
   ```

4. **Deploy Application**
   ```bash
   # Clone repository
   git clone git@github.com:petgully/accounting-api.git
   cd accounting-api
   
   # Build and run
   docker build -t accounting-api .
   docker run -d \
     --name accounting-api \
     -p 8000:8000 \
     -e API_KEY=your_secure_api_key \
     -e DB_HOST=localhost \
     -e DB_USER=accounting_api \
     -e DB_PASS=secure_password \
     -e DB_NAME=accounting_api \
     accounting-api
   ```

5. **Set up Reverse Proxy (Optional)**
   ```bash
   # Install Nginx
   sudo apt install nginx
   
   # Configure Nginx
   sudo nano /etc/nginx/sites-available/accounting-api
   ```

   Nginx configuration:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://localhost:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

6. **Enable SSL (Optional)**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

### Environment Configuration

Create a `.env` file on your Lightsail instance:

```bash
API_KEY=your_secure_api_key_here
DB_HOST=localhost
DB_USER=accounting_api
DB_PASS=your_secure_password
DB_NAME=accounting_api
OPENAI_API_KEY=your_openai_key_here
ML_THRESHOLD=0.75
```

## 🔧 Development

### Project Structure

```
accounting-api/
├── app.py                 # FastAPI application
├── rules_engine.py        # Database-driven rules engine
├── database_schema.sql    # MySQL schema
├── googlesheetscript.gs   # Google Apps Script
├── Dockerfile            # Docker configuration
├── requirements.txt      # Python dependencies
├── context.txt          # System context
├── README.md            # This file
└── RULES_SYSTEM.md      # Rules system documentation
```

### Adding New Rules

1. **Via Database** (Recommended):
   ```sql
   INSERT INTO rules (name, priority, keywords, main_category, sub_category, created_by)
   VALUES ('New Rule', 10, '["KEYWORD1", "KEYWORD2"]', 'Category', 'Subcategory', 'manual');
   ```

2. **Via API** (Auto-learning):
   - Manually categorize transactions in Google Sheets
   - Use "Approve & Publish" to trigger rule learning

### Testing

```bash
# Run tests
python -m pytest tests/

# Test specific endpoint
curl -X POST "http://localhost:8000/classify" \
  -H "X-API-Key: test_key" \
  -H "Content-Type: application/json" \
  -d '{"rows": [{"date": "2024-01-15", "description": "test", "amount": 100}]}'
```

## 📚 Documentation

- [Rules System Documentation](RULES_SYSTEM.md) - Detailed rules system explanation
- [API Reference](docs/api.md) - Complete API documentation
- [Deployment Guide](docs/deployment.md) - Detailed deployment instructions
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue on GitHub
- Check the troubleshooting guide
- Review the API documentation

## 🔄 Changelog

### v2.0.0
- Database-driven rules system
- Automatic rule learning
- Enhanced Google Sheets integration
- Performance optimizations
- Comprehensive monitoring

### v1.0.0
- Initial release
- File-based rules system
- Basic categorization
- Google Sheets integration