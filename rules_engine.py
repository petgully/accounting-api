# -*- coding: utf-8 -*-

"""
Database-driven rule engine for bank transaction categorization.

This module replaces the static rules.py file with a dynamic system that:
1. Loads rules from MySQL database
2. Caches rules for performance
3. Supports rule learning from manual categorizations
4. Handles salary name matching separately
"""

from typing import Tuple, Optional, List, Dict, Any
import mysql.connector
import json
import os
from datetime import datetime, timedelta
import threading
import time

class RulesEngine:
    def __init__(self, db_config: Dict[str, str]):
        """
        Initialize the rules engine with database configuration.
        
        Args:
            db_config: Dictionary containing DB_HOST, DB_USER, DB_PASS, DB_NAME
        """
        self.db_config = db_config
        self.rules_cache = []
        self.salary_rules_cache = []
        self.cache_timestamp = None
        self.cache_ttl = 300  # 5 minutes cache TTL
        self.lock = threading.Lock()
        
        # Load initial rules
        self._load_rules()
    
    def _get_connection(self):
        """Get database connection."""
        return mysql.connector.connect(
            host=self.db_config['host'],
            user=self.db_config['user'],
            password=self.db_config['password'],
            database=self.db_config['database']
        )
    
    def _load_rules(self):
        """Load rules from database and cache them."""
        with self.lock:
            try:
                conn = self._get_connection()
                cursor = conn.cursor(dictionary=True)
                
                # Load keyword rules
                cursor.execute("""
                    SELECT name, priority, keywords, main_category, sub_category, 
                           frequency, confidence, is_active
                    FROM rules 
                    WHERE is_active = TRUE 
                    ORDER BY priority ASC, frequency DESC
                """)
                self.rules_cache = cursor.fetchall()
                
                # Load salary rules
                cursor.execute("""
                    SELECT team_name, employee_names 
                    FROM salary_rules
                """)
                self.salary_rules_cache = cursor.fetchall()
                
                self.cache_timestamp = time.time()
                
                cursor.close()
                conn.close()
                
                print(f"Loaded {len(self.rules_cache)} rules and {len(self.salary_rules_cache)} salary rules")
                
            except Exception as e:
                print(f"Error loading rules: {e}")
                self.rules_cache = []
                self.salary_rules_cache = []
    
    def _is_cache_valid(self) -> bool:
        """Check if cache is still valid."""
        if self.cache_timestamp is None:
            return False
        return time.time() - self.cache_timestamp < self.cache_ttl
    
    def _ensure_fresh_rules(self):
        """Ensure rules are fresh, reload if needed."""
        if not self._is_cache_valid():
            self._load_rules()
    
    def apply_rules(self, narration: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """
        Apply rules to categorize a transaction.
        
        Args:
            narration: Transaction description text
            
        Returns:
            Tuple of (main_category, sub_category, rule_hit_name) or (None, None, None)
        """
        if narration is None or not narration.strip():
            return (None, None, None)
        
        self._ensure_fresh_rules()
        
        text = str(narration).upper().strip()
        
        # 1) Salary name matching (highest priority)
        salary_result = self._check_salary_rules(text)
        if salary_result[0]:
            return salary_result
        
        # 2) Keyword rules matching
        keyword_result = self._check_keyword_rules(text)
        if keyword_result[0]:
            return keyword_result
        
        # 3) No match found
        return (None, None, None)
    
    def _check_salary_rules(self, text: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """Check salary rules for employee name matching."""
        for salary_rule in self.salary_rules_cache:
            try:
                employee_names = json.loads(salary_rule['employee_names'])
                team_name = salary_rule['team_name']
                
                for name in employee_names:
                    if name in text and any(keyword in text for keyword in ["SALARY", "EXPENSES", "NEFT DR", "IMPS", "TPT"]):
                        return ("Salaries & Wages", team_name, f"Salary name: {name}")
            except (json.JSONDecodeError, KeyError) as e:
                print(f"Error parsing salary rule: {e}")
                continue
        
        return (None, None, None)
    
    def _check_keyword_rules(self, text: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """Check keyword rules for categorization."""
        for rule in self.rules_cache:
            try:
                keywords = json.loads(rule['keywords'])
                
                # Check if any keyword matches
                if any(keyword in text for keyword in keywords):
                    # Update rule frequency
                    self._increment_rule_frequency(rule['id'])
                    
                    return (
                        rule['main_category'],
                        rule['sub_category'],
                        rule['name']
                    )
            except (json.JSONDecodeError, KeyError) as e:
                print(f"Error parsing rule keywords: {e}")
                continue
        
        return (None, None, None)
    
    def _increment_rule_frequency(self, rule_id: int):
        """Increment rule frequency in database (async)."""
        def update_frequency():
            try:
                conn = self._get_connection()
                cursor = conn.cursor()
                cursor.execute(
                    "UPDATE rules SET frequency = frequency + 1 WHERE id = %s",
                    (rule_id,)
                )
                conn.commit()
                cursor.close()
                conn.close()
            except Exception as e:
                print(f"Error updating rule frequency: {e}")
        
        # Run in background thread
        thread = threading.Thread(target=update_frequency)
        thread.daemon = True
        thread.start()
    
    def learn_new_rules(self, transactions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Learn new rules from manually categorized transactions.
        
        Args:
            transactions: List of transaction dictionaries with categorization data
            
        Returns:
            Dictionary with learning results
        """
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            new_rules = []
            rules_created = 0
            
            # Group transactions by normalized description and category
            transaction_groups = {}
            
            for tx in transactions:
                if (tx.get('main_category_suggested') == 'Uncategorized' and 
                    tx.get('main_category') != 'Uncategorized' and
                    tx.get('description')):
                    
                    key = tx['description'].upper().strip()
                    if key not in transaction_groups:
                        transaction_groups[key] = {
                            'count': 0,
                            'main_category': tx['main_category'],
                            'sub_category': tx['sub_category'],
                            'descriptions': []
                        }
                    
                    transaction_groups[key]['count'] += 1
                    transaction_groups[key]['descriptions'].append(tx['description'])
            
            # Create rules for groups with 2+ transactions
            for desc_key, group_data in transaction_groups.items():
                if group_data['count'] >= 2:
                    # Extract keywords from description
                    keywords = self._extract_keywords(desc_key)
                    
                    if keywords:
                        # Check if similar rule already exists
                        if not self._rule_exists(keywords, group_data['main_category'], group_data['sub_category']):
                            rule_name = f"Auto-learned: {keywords[0]}"
                            if len(keywords) > 1:
                                rule_name += f" +{len(keywords)-1}"
                            
                            # Insert new rule
                            cursor.execute("""
                                INSERT INTO rules (name, priority, keywords, main_category, sub_category, 
                                                 frequency, confidence, created_by)
                                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                            """, (
                                rule_name,
                                50,  # Medium priority for auto-learned rules
                                json.dumps(keywords),
                                group_data['main_category'],
                                group_data['sub_category'],
                                group_data['count'],
                                0.95,
                                'auto_learned'
                            ))
                            
                            rules_created += 1
                            new_rules.append({
                                'name': rule_name,
                                'keywords': keywords,
                                'main_category': group_data['main_category'],
                                'sub_category': group_data['sub_category'],
                                'frequency': group_data['count']
                            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            # Invalidate cache to force reload
            self.cache_timestamp = None
            
            return {
                'success': True,
                'rules_created': rules_created,
                'new_rules': new_rules
            }
            
        except Exception as e:
            print(f"Error learning new rules: {e}")
            return {
                'success': False,
                'error': str(e),
                'rules_created': 0,
                'new_rules': []
            }
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract meaningful keywords from transaction description."""
        # Get existing keywords to avoid duplicates
        existing_keywords = set()
        for rule in self.rules_cache:
            try:
                keywords = json.loads(rule['keywords'])
                existing_keywords.update(keywords)
            except:
                continue
        
        # Extract words
        words = text.split()
        keywords = []
        
        for word in words:
            word = word.strip()
            if (len(word) >= 3 and 
                word not in existing_keywords and
                word not in ["THE", "AND", "FOR", "WITH", "FROM", "TO", "OF", "IN", "ON", "AT", "BY", 
                            "PAYMENT", "TRANSFER", "NEFT", "IMPS", "UPI", "DR", "CR"] and
                word.isalnum() and
                not word.isdigit()):
                keywords.append(word)
        
        return keywords[:5]  # Limit to 5 keywords
    
    def _rule_exists(self, keywords: List[str], main_category: str, sub_category: str) -> bool:
        """Check if a similar rule already exists."""
        for rule in self.rules_cache:
            try:
                rule_keywords = json.loads(rule['keywords'])
                if (rule['main_category'] == main_category and 
                    rule['sub_category'] == sub_category and
                    any(kw in rule_keywords for kw in keywords)):
                    return True
            except:
                continue
        return False
    
    def get_rule_statistics(self) -> Dict[str, Any]:
        """Get statistics about current rules."""
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Get rule counts
            cursor.execute("SELECT COUNT(*) FROM rules WHERE is_active = TRUE")
            total_rules = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM rules WHERE created_by = 'auto_learned' AND is_active = TRUE")
            auto_learned_rules = cursor.fetchone()[0]
            
            # Get transaction counts
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_transactions,
                    COUNT(CASE WHEN reviewed_at IS NOT NULL THEN 1 END) as verified_transactions,
                    COUNT(CASE WHEN confidence > 0.8 THEN 1 END) as high_confidence_transactions
                FROM transactions_canonical
            """)
            tx_stats = cursor.fetchone()
            
            # Get top categories
            cursor.execute("""
                SELECT 
                    cm.name as main_category,
                    COUNT(*) as transaction_count
                FROM transactions_canonical tc
                LEFT JOIN categories_main cm ON tc.main_category_id = cm.id
                WHERE tc.reviewed_at IS NOT NULL
                GROUP BY cm.name
                ORDER BY transaction_count DESC
                LIMIT 10
            """)
            top_categories = [{'category': row[0], 'count': row[1]} for row in cursor.fetchall()]
            
            cursor.close()
            conn.close()
            
            return {
                'total_rules': total_rules,
                'auto_learned_rules': auto_learned_rules,
                'manual_rules': total_rules - auto_learned_rules,
                'database_stats': {
                    'total_transactions': tx_stats[0],
                    'verified_transactions': tx_stats[1],
                    'high_confidence_transactions': tx_stats[2]
                },
                'top_categories': top_categories
            }
            
        except Exception as e:
            print(f"Error getting rule statistics: {e}")
            return {
                'total_rules': 0,
                'auto_learned_rules': 0,
                'manual_rules': 0,
                'database_stats': {
                    'total_transactions': 0,
                    'verified_transactions': 0,
                    'high_confidence_transactions': 0
                },
                'top_categories': []
            }
    
    def refresh_cache(self):
        """Manually refresh the rules cache."""
        self._load_rules()

# Global rules engine instance
_rules_engine = None

def get_rules_engine() -> RulesEngine:
    """Get the global rules engine instance."""
    global _rules_engine
    if _rules_engine is None:
        db_config = {
            'host': os.getenv('DB_HOST'),
            'user': os.getenv('DB_USER'),
            'password': os.getenv('DB_PASS'),
            'database': os.getenv('DB_NAME')
        }
        _rules_engine = RulesEngine(db_config)
    return _rules_engine

def apply_rules(narration: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Apply rules to categorize a transaction.
    This function maintains compatibility with the old rules.py interface.
    
    Args:
        narration: Transaction description text
        
    Returns:
        Tuple of (main_category, sub_category, rule_hit_name) or (None, None, None)
    """
    engine = get_rules_engine()
    return engine.apply_rules(narration)
