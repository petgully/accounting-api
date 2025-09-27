#!/usr/bin/env python3
"""
Script to insert sample rules data into the rules table.
"""

import mysql.connector
import json

# Database configuration
DB_CONFIG = {
    'host': 'petgully-dbserver.cmzwm2y64qh8.us-east-1.rds.amazonaws.com',
    'user': 'admin',
    'password': 'care6886',
    'database': 'petgully_db',
    'connect_timeout': 30,
    'autocommit': True
}

def insert_sample_rules():
    """Insert sample rules data."""
    
    # Sample rules data
    rules_data = [
        # Grooming Inventory
        ('Vet India Pharma', 10, '["VET INDIA", "PHARMACEUTICALS"]', 'Grooming Inventory', 'Vet India Pharma (VIP)', 'manual'),
        ('Amazon', 20, '["AMAZON"]', 'Grooming Inventory', 'Amazon', 'manual'),
        ('Swiggy', 10, '["SWIGGY", "INSTAMART"]', 'Office Overhead', 'Swiggy', 'manual'),
        ('Bajaj Finance', 10, '["BAJAJ FINANCE"]', 'Loan EMI Payments', 'Bajaj Finance', 'manual'),
        ('Airtel', 10, '["AIRTEL", "AIRTELIN"]', 'Telephone & Internet', 'Airtel Mobile and Internet', 'manual'),
    ]
    
    # Sample salary rules data
    salary_rules_data = [
        ('Back Office', '["DASARI VAMSHI", "DUSARI NARESH", "KARAN SINGH"]'),
        ('Operations Team', '["ARJUN DR EMP", "BALAJI GR", "GARIKAPATI PRADEEP"]'),
        ('Customer Care', '["BOBBILI ARCHANA", "KASIMALLA VAMSHI VARDHAN"]'),
    ]
    
    try:
        print("Connecting to AWS RDS database...")
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("✅ Connected successfully!")
        
        # Insert rules
        print("Inserting sample rules...")
        insert_rules_sql = """
        INSERT IGNORE INTO rules (name, priority, keywords, main_category, sub_category, created_by) 
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        
        for rule in rules_data:
            cursor.execute(insert_rules_sql, rule)
        
        print(f"✅ Inserted {len(rules_data)} rules!")
        
        # Insert salary rules
        print("Inserting sample salary rules...")
        insert_salary_sql = """
        INSERT IGNORE INTO salary_rules (team_name, employee_names) 
        VALUES (%s, %s)
        """
        
        for salary_rule in salary_rules_data:
            cursor.execute(insert_salary_sql, salary_rule)
        
        print(f"✅ Inserted {len(salary_rules_data)} salary rules!")
        
        # Verify data
        cursor.execute("SELECT COUNT(*) FROM rules")
        rules_count = cursor.fetchone()[0]
        print(f"📊 Total rules in database: {rules_count}")
        
        cursor.execute("SELECT COUNT(*) FROM salary_rules")
        salary_count = cursor.fetchone()[0]
        print(f"📊 Total salary rules in database: {salary_count}")
        
        print("\n🎉 Sample data inserted successfully!")
        
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
    insert_sample_rules()
