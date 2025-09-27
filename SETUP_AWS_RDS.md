# AWS RDS Database Setup Guide

This guide explains how to set up the accounting API with your existing AWS RDS database.

## Overview

The accounting API has been updated to work with your existing AWS RDS database (`petgully_db`) instead of creating a new database. The system will create the necessary tables for the rules engine while preserving your existing data.

## Database Configuration

The system is now configured to use these AWS RDS credentials:
- **Host**: `petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com`
- **User**: `admin`
- **Password**: `care6886`
- **Database**: `petgully_db`

## Existing Tables

Your database already contains these tables:
- `apartments`
- `categories_main`
- `customers`
- `transactions_canonical`
- `transactions_raw`

## New Tables to be Created

The setup will create these additional tables:
- `rules` - Stores categorization rules
- `salary_rules` - Stores employee name matching rules

## Setup Steps

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Create Rules Tables

Run the script to create the necessary tables:

```bash
python create_rules_tables.py
```

This will create:
- `rules` table for transaction categorization rules
- `salary_rules` table for employee name matching

### 3. Insert Sample Data (Optional)

To get started with some sample rules:

```bash
python insert_sample_rules.py
```

### 4. Test Database Connection

Verify the connection works:

```bash
python test_db_connection.py
```

### 5. Run the API

Start the accounting API:

```bash
python app.py
```

## Environment Variables

Create a `.env` file with these variables:

```env
# API Configuration
API_KEY=your_secure_api_key_here

# Database Configuration (AWS RDS)
DB_HOST=petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_PASS=care6886
DB_NAME=petgully_db

# Optional: OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here

# ML Configuration
ML_THRESHOLD=0.75
```

## API Endpoints

Once running, the API provides these endpoints:

- `GET /` - API information
- `GET /health` - Health check
- `POST /classify` - Categorize transactions
- `POST /sync` - Store verified transactions and learn rules
- `GET /rule-stats` - Get rule statistics
- `POST /refresh-rules` - Refresh rules cache

## How It Works

1. **Transaction Classification**: The API uses database-driven rules to categorize transactions
2. **Rule Learning**: When you manually categorize transactions via the `/sync` endpoint, the system learns new rules
3. **Fallback**: If no rules match, it falls back to ML classification
4. **Salary Matching**: Special handling for employee salary transactions

## Database Schema

### Rules Table
```sql
CREATE TABLE rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    priority INT DEFAULT 50,
    keywords JSON NOT NULL,
    main_category VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    frequency INT DEFAULT 0,
    confidence DECIMAL(3,2) DEFAULT 0.95,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by ENUM('manual', 'auto_learned') DEFAULT 'manual'
);
```

### Salary Rules Table
```sql
CREATE TABLE salary_rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(50) NOT NULL,
    employee_names JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## Troubleshooting

### Connection Issues
- Ensure your AWS RDS instance is running
- Check security groups allow connections from your IP
- Verify the credentials are correct

### Table Creation Issues
- Ensure the database user has CREATE TABLE permissions
- Check if tables already exist (they won't be overwritten)

### API Issues
- Check the API_KEY is set correctly
- Verify all environment variables are loaded
- Check the logs for specific error messages

## Next Steps

1. Run the setup scripts to create the tables
2. Test the API with sample transactions
3. Use the `/sync` endpoint to feed in your existing categorized transactions
4. Monitor the `/rule-stats` endpoint to see rule learning progress
5. Add more manual rules as needed

## Support

If you encounter any issues:
1. Check the database connection with `test_db_connection.py`
2. Verify the tables were created successfully
3. Check the API logs for specific error messages
4. Ensure all environment variables are set correctly
