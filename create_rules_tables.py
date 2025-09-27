#!/usr/bin/env python3
"""
Simple script to create only the rules tables in the existing AWS RDS database.
"""

import mysql.connector
import time

# Database configuration
DB_CONFIG = {
    'host': 'petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com',
    'user': 'admin',
    'password': 'care6886',
    'database': 'petgully_db',
    'connect_timeout': 30,
    'autocommit': True
}

def create_rules_tables():
    """Create only the rules and salary_rules tables."""
    
    # SQL to create the rules table
    create_rules_sql = """
    CREATE TABLE IF NOT EXISTS rules (
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
        created_by ENUM('manual', 'auto_learned') DEFAULT 'manual',
        INDEX idx_priority (priority),
        INDEX idx_main_category (main_category),
        INDEX idx_active (is_active)
    )
    """
    
    # SQL to create the salary_rules table
    create_salary_rules_sql = """
    CREATE TABLE IF NOT EXISTS salary_rules (
        id INT AUTO_INCREMENT PRIMARY KEY,
        team_name VARCHAR(50) NOT NULL,
        employee_names JSON NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_team (team_name)
    )
    """
    
    try:
        print("Connecting to AWS RDS database...")
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("✅ Connected successfully!")
        
        # Create rules table
        print("Creating rules table...")
        cursor.execute(create_rules_sql)
        print("✅ Rules table created!")
        
        # Create salary_rules table
        print("Creating salary_rules table...")
        cursor.execute(create_salary_rules_sql)
        print("✅ Salary rules table created!")
        
        # Verify tables exist
        cursor.execute("SHOW TABLES LIKE 'rules'")
        if cursor.fetchone():
            print("✅ Rules table verified!")
        
        cursor.execute("SHOW TABLES LIKE 'salary_rules'")
        if cursor.fetchone():
            print("✅ Salary rules table verified!")
        
        print("\n🎉 Database setup complete!")
        print("You can now run the accounting API with the rules engine.")
        
    except mysql.connector.Error as e:
        print(f"❌ Database error: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    create_rules_tables()
