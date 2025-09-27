-- =====================================================
-- ACCOUNTING-API DATABASE SCHEMA
-- =====================================================
-- This schema supports the new accounting-api system with database-driven rules

-- Drop existing tables if they exist (for fresh setup)
DROP TABLE IF EXISTS transactions_canonical;
DROP TABLE IF EXISTS transactions_raw;
DROP TABLE IF EXISTS categories_main;
DROP TABLE IF EXISTS rules;

-- =====================================================
-- CATEGORIES TABLE
-- =====================================================
CREATE TABLE categories_main (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
);

-- Insert default categories
INSERT INTO categories_main (name, description) VALUES
('Uncategorized', 'Transactions that could not be automatically categorized'),
('Grooming Inventory', 'Supplies and materials for pet grooming services'),
('Vehicle Subscription', 'Vehicle-related subscriptions and services'),
('Fuel', 'Fuel expenses for vehicles'),
('Office Overhead', 'General office operational expenses'),
('Electricity maintance & Bill', 'Electricity bills and maintenance'),
('Telephone & Internet', 'Communication and internet services'),
('Bank Charges', 'Banking fees and charges'),
('Petty Cash', 'Small cash transactions'),
('Loan EMI Payments', 'Loan and EMI payments'),
('Admin Expenses', 'Administrative expenses'),
('Employee Welfare', 'Employee-related benefits and expenses'),
('Customer Refund', 'Refunds to customers'),
('Repari & Maintenance', 'Repair and maintenance expenses'),
('Tax & Duties', 'Tax payments and duties'),
('Salaries & Wages', 'Employee salary payments');

-- =====================================================
-- RULES TABLE
-- =====================================================
CREATE TABLE rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    priority INT DEFAULT 50,
    keywords JSON NOT NULL,  -- Array of keywords to match
    main_category VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    frequency INT DEFAULT 0,  -- How many times this rule has been used
    confidence DECIMAL(3,2) DEFAULT 0.95,  -- Rule confidence score
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by ENUM('manual', 'auto_learned') DEFAULT 'manual',
    INDEX idx_priority (priority),
    INDEX idx_main_category (main_category),
    INDEX idx_active (is_active),
    INDEX idx_keywords ((CAST(keywords AS CHAR(1000) ARRAY))),
    FOREIGN KEY (main_category) REFERENCES categories_main(name) ON UPDATE CASCADE
);

-- Insert initial rules from the old system
INSERT INTO rules (name, priority, keywords, main_category, sub_category, created_by) VALUES
-- Grooming Inventory
('Vet India Pharma', 10, '["VET INDIA", "PHARMACEUTICALS"]', 'Grooming Inventory', 'Vet India Pharma (VIP)', 'manual'),
('Nutan Medical', 10, '["NUTAN MEDICAL"]', 'Grooming Inventory', 'Nutan Medical', 'manual'),
('ABK Imports', 10, '["ABK IMPORTS"]', 'Grooming Inventory', 'ABK Imports', 'manual'),
('Amazon', 20, '["AMAZON"]', 'Grooming Inventory', 'Amazon', 'manual'),
('Pubscribe', 15, '["PUBSCRIBE"]', 'Grooming Inventory', 'Pubscribe Enterprises', 'manual'),
('Anasuya', 15, '["ANASUYA"]', 'Grooming Inventory', 'Anasuya Food Tech', 'manual'),

-- Vehicle Subscription
('Imobility', 10, '["IMOBILITI", "IMOBILITY"]', 'Vehicle Subscription', 'Imobility Subscription', 'manual'),

-- Fuel
('Fuel Pump', 15, '["DEEPAKDIRECTORICICI"]', 'Fuel', 'Fuel - Diesel & Petrol', 'manual'),
('Fuel Generic', 30, '["PETROL", "DIESEL", "BPCL", "UFILL", "BP PETROL"]', 'Fuel', 'Fuel - Diesel & Petrol', 'manual'),

-- Office Overhead
('Swiggy', 10, '["SWIGGY", "INSTAMART"]', 'Office Overhead', 'Swiggy', 'manual'),
('Water Tanker', 30, '["TANKER", "WATER TANKER", "KRUPAKAR"]', 'Office Overhead', 'Water Tanker', 'manual'),
('Milk', 30, '["MILK"]', 'Office Overhead', 'Milk', 'manual'),
('Garbage', 30, '["GARBAGE"]', 'Office Overhead', 'Garbage', 'manual'),
('Electrician', 30, '["ELECTRICIAN", "ELECTRICAL"]', 'Office Overhead', 'Electrician', 'manual'),
('Water Bill', 40, '["BILLDKHYDERABADMETRO", "HYDERABAD METRO"]', 'Office Overhead', 'Water Bill', 'manual'),

-- Electricity
('Electricity Bill', 20, '["SOUTHERNPOWERDISTRIB"]', 'Electricity maintance & Bill', 'Electricity Bill', 'manual'),

-- Telco/Internet
('Airtel', 10, '["AIRTEL", "AIRTELIN", "WWW AIRTEL IN"]', 'Telephone & Internet', 'Airtel Mobile and Internet', 'manual'),

-- Bank Charges
('IMPS P2P Fee', 20, '["IMPS P2P", "MIR"]', 'Bank Charges', 'Processing Fee', 'manual'),
('ATM/Withdr TDS', 20, '["TDS CASH WITHDRAWAL"]', 'Bank Charges', 'Processing Fee', 'manual'),

-- Petty Cash
('Petty Cash HIMA', 20, '["HIMADIRECTOR"]', 'Petty Cash', 'Petty Cash (Mobile Grooming)', 'manual'),

-- Loan EMI Payments
('Bajaj Finance', 10, '["BAJAJ FINANCE"]', 'Loan EMI Payments', 'Bajaj Finance', 'manual'),
('Godrej Finance', 10, '["GODREJFINANCE"]', 'Loan EMI Payments', 'Godrej Finance', 'manual'),
('UGRO Capital', 10, '["UGRO CAPITAL"]', 'Loan EMI Payments', 'UGRO CAPITAL', 'manual'),
('India Infoline', 10, '["INFOLINE"]', 'Loan EMI Payments', 'India Infoline Finance', 'manual'),
('Unity Small', 10, '["UNITY SMALL", "UNITYSMALL"]', 'Loan EMI Payments', 'Unity Small Finance', 'manual'),
('Shriram', 10, '["SHRIRAM"]', 'Loan EMI Payments', 'Shriram Finance', 'manual'),
('HDFC EMI (CHQ)', 40, '["EMI ", " CHQ S"]', 'Loan EMI Payments', 'HDFC Loan EMI', 'manual'),
('HandLoan Rao', 10, '["VENKATESWARA RAO"]', 'Loan EMI Payments', 'Venkateswara Rao HandLoan', 'manual'),
('HandLoan Sanjay', 10, '["SANJAY PAN"]', 'Loan EMI Payments', 'Sanjay Pan HandLoan', 'manual'),

-- Admin Expenses
('Slot Books', 25, '["SLOT", "BOOKS"]', 'Admin Expenses', 'Slot Books', 'manual'),
('Vet Doctor', 30, '["DRKARTHEEK", "VET", "DOCTOR", "KARTHEEK"]', 'Admin Expenses', 'Veterinary Doctor Charges', 'manual'),

-- Employee Welfare
('Hostel Fee', 15, '["HOSTEL", "SRIPAL REDDY"]', 'Employee Welfare', 'Hostel Fee for Employees', 'manual'),

-- Customer Refund
('Customer Refund', 25, '["REFUND", "CUSTOMER", "SLOT"]', 'Customer Refund', 'Customer Refund of Slots', 'manual'),

-- Repair & Maintenance
('Generator Oil', 25, '["GENERATOR OIL"]', 'Repari & Maintenance', 'Generator Oil', 'manual'),
('Plumbing', 15, '["PLUMBING", "MANOJ MALIK"]', 'Repari & Maintenance', 'Plumbing Maintenance', 'manual'),
('Water Wash', 25, '["WATER WASH"]', 'Repari & Maintenance', 'Water Wash', 'manual'),

-- Tax & Duties
('TDS Payment', 25, '["CBDT"]', 'Tax & Duties', 'TDS Payment', 'manual'),
('GST Payment', 25, '["GST"]', 'Tax & Duties', 'GST Payment', 'manual'),
('EPFO', 15, '["PSIVR"]', 'Tax & Duties', 'EPFO', 'manual');

-- =====================================================
-- TRANSACTIONS RAW TABLE
-- =====================================================
CREATE TABLE transactions_raw (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hash VARCHAR(64) NOT NULL UNIQUE,
    posted_at DATE NOT NULL,
    description_raw TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2),
    account VARCHAR(50),
    currency VARCHAR(10) DEFAULT 'INR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_hash (hash),
    INDEX idx_posted_at (posted_at),
    INDEX idx_account (account)
);

-- =====================================================
-- TRANSACTIONS CANONICAL TABLE
-- =====================================================
CREATE TABLE transactions_canonical (
    id INT AUTO_INCREMENT PRIMARY KEY,
    raw_hash VARCHAR(64) NOT NULL,
    posted_at DATE NOT NULL,
    normalized_desc TEXT,
    amount DECIMAL(15,2) NOT NULL,
    debit_credit ENUM('debit', 'credit') NOT NULL,
    vendor_text VARCHAR(100),
    main_category_id INT,
    sub_category_text VARCHAR(100),
    confidence DECIMAL(3,2) DEFAULT 0.0,
    source ENUM('sheet', 'api', 'manual') DEFAULT 'sheet',
    reviewed_at TIMESTAMP NULL,
    rule_hit VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_raw_hash (raw_hash),
    INDEX idx_posted_at (posted_at),
    INDEX idx_main_category (main_category_id),
    INDEX idx_reviewed (reviewed_at),
    INDEX idx_confidence (confidence),
    FOREIGN KEY (raw_hash) REFERENCES transactions_raw(hash) ON DELETE CASCADE,
    FOREIGN KEY (main_category_id) REFERENCES categories_main(id) ON UPDATE CASCADE
);

-- =====================================================
-- SALARY RULES TABLE (for employee name matching)
-- =====================================================
CREATE TABLE salary_rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(50) NOT NULL,
    employee_names JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_team (team_name)
);

-- Insert salary rules
INSERT INTO salary_rules (team_name, employee_names) VALUES
('Back Office', '["DASARI VAMSHI", "DUSARI NARESH", "KARAN SINGH", "KOKI SRIHARI REDDY"]'),
('Operations Team', '["ARJUN DR EMP", "BALAJI GR", "GARIKAPATI PRADEEP", "KARTHIK DR", "KOLIPAKA BALAKRISHNA", "MALLESHWARI", "NANDI GAMA SHIVA KUMAR", "NELOJEE SAI KUMAR", "P SHIVA KUMAR", "PALTYA RAMESH", "PINAPOTHU RAMU", "PRASAD DR", "RAJESH DR", "SABAVATH SHIVA", "SACHIN GAUR", "SALAVATH SRINU", "THAMMICHETTY KOTESH", "NABADWIP DEBBARMA"]'),
('Customer Care', '["BOBBILI ARCHANA", "KASIMALLA VAMSHI VARDHAN", "SHAHEEDA", "YELIMALA PRAVEEN"]');

-- =====================================================
-- PERFORMANCE OPTIMIZATIONS
-- =====================================================

-- Create indexes for common queries
CREATE INDEX idx_rules_keywords_search ON rules ((CAST(keywords AS CHAR(1000) ARRAY)));
CREATE INDEX idx_transactions_amount ON transactions_canonical (amount);
CREATE INDEX idx_transactions_vendor ON transactions_canonical (vendor_text);
CREATE INDEX idx_transactions_subcategory ON transactions_canonical (sub_category_text);

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for rule statistics
CREATE VIEW rule_statistics AS
SELECT 
    r.id,
    r.name,
    r.priority,
    r.main_category,
    r.sub_category,
    r.frequency,
    r.confidence,
    r.is_active,
    r.created_by,
    r.created_at,
    r.updated_at
FROM rules r
WHERE r.is_active = TRUE
ORDER BY r.priority ASC, r.frequency DESC;

-- View for transaction categorization summary
CREATE VIEW transaction_summary AS
SELECT 
    tc.posted_at,
    tc.normalized_desc,
    tc.amount,
    tc.vendor_text,
    cm.name as main_category,
    tc.sub_category_text,
    tc.confidence,
    tc.rule_hit,
    tc.reviewed_at
FROM transactions_canonical tc
LEFT JOIN categories_main cm ON tc.main_category_id = cm.id
ORDER BY tc.posted_at DESC;

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

DELIMITER //

-- Procedure to learn new rules from manual categorizations
CREATE PROCEDURE LearnNewRules()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_normalized_desc TEXT;
    DECLARE v_vendor_text VARCHAR(100);
    DECLARE v_main_category VARCHAR(100);
    DECLARE v_sub_category VARCHAR(100);
    DECLARE v_frequency INT;
    DECLARE v_confidence DECIMAL(3,2);
    DECLARE v_keywords JSON;
    DECLARE v_rule_name VARCHAR(200);
    DECLARE v_keyword_count INT;
    
    DECLARE rule_cursor CURSOR FOR
        SELECT 
            tc.normalized_desc,
            tc.vendor_text,
            cm.name as main_category,
            tc.sub_category_text,
            COUNT(*) as frequency,
            AVG(tc.confidence) as avg_confidence
        FROM transactions_canonical tc
        LEFT JOIN categories_main cm ON tc.main_category_id = cm.id
        WHERE tc.reviewed_at IS NOT NULL 
        AND tc.confidence > 0.8
        AND tc.normalized_desc IS NOT NULL
        AND tc.normalized_desc != ''
        AND cm.name != 'Uncategorized'
        GROUP BY tc.normalized_desc, tc.vendor_text, tc.sub_category_text, cm.name
        HAVING COUNT(*) >= 2
        ORDER BY frequency DESC, avg_confidence DESC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN rule_cursor;
    
    rule_loop: LOOP
        FETCH rule_cursor INTO v_normalized_desc, v_vendor_text, v_main_category, v_sub_category, v_frequency, v_confidence;
        
        IF done THEN
            LEAVE rule_loop;
        END IF;
        
        -- Extract keywords from normalized description
        SET v_keywords = JSON_ARRAY();
        SET v_keyword_count = 0;
        
        -- Simple keyword extraction (can be enhanced)
        SET v_keywords = JSON_ARRAY(v_normalized_desc);
        
        -- Create rule name
        SET v_rule_name = CONCAT('Auto-learned: ', SUBSTRING(v_normalized_desc, 1, 50));
        
        -- Insert new rule if it doesn't exist
        INSERT IGNORE INTO rules (name, priority, keywords, main_category, sub_category, frequency, confidence, created_by)
        VALUES (v_rule_name, 50, v_keywords, v_main_category, v_sub_category, v_frequency, v_confidence, 'auto_learned');
        
    END LOOP;
    
    CLOSE rule_cursor;
    
    -- Return count of new rules learned
    SELECT ROW_COUNT() as new_rules_learned;
    
END //

DELIMITER ;

-- =====================================================
-- SAMPLE DATA FOR TESTING
-- =====================================================

-- Insert some sample transactions for testing
INSERT INTO transactions_raw (hash, posted_at, description_raw, amount, balance_after, account, currency) VALUES
('sample_hash_1', '2024-01-15', 'UPI-MR-SWIGGY-123456', -150.00, 5000.00, 'HDFC1681', 'INR'),
('sample_hash_2', '2024-01-15', 'BAJAJ FINANCE EMI', -2500.00, 4750.00, 'HDFC1681', 'INR'),
('sample_hash_3', '2024-01-16', 'VET INDIA PHARMACEUTICALS', -500.00, 4250.00, 'HDFC1681', 'INR');

INSERT INTO transactions_canonical (raw_hash, posted_at, normalized_desc, amount, debit_credit, vendor_text, main_category_id, sub_category_text, confidence, source, rule_hit) VALUES
('sample_hash_1', '2024-01-15', 'UPI-MR-SWIGGY-123456', -150.00, 'debit', 'UPI-MR', 5, 'Swiggy', 0.95, 'sheet', 'Swiggy'),
('sample_hash_2', '2024-01-15', 'BAJAJ FINANCE EMI', -2500.00, 'debit', 'BAJAJ FINANCE', 10, 'Bajaj Finance', 0.95, 'sheet', 'Bajaj Finance'),
('sample_hash_3', '2024-01-16', 'VET INDIA PHARMACEUTICALS', -500.00, 'debit', 'VET INDIA', 2, 'Vet India Pharma (VIP)', 0.95, 'sheet', 'Vet India Pharma');

-- =====================================================
-- GRANTS AND PERMISSIONS
-- =====================================================

-- Create a user for the application (adjust as needed)
-- CREATE USER 'accounting_api'@'%' IDENTIFIED BY 'your_secure_password';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON accounting_api.* TO 'accounting_api'@'%';
-- FLUSH PRIVILEGES;
