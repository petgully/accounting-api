# Rules System Documentation

## Overview

The Accounting API v2.0 uses a sophisticated database-driven rules system for transaction categorization. This system replaces the static file-based rules with a dynamic, learnable system that automatically improves over time.

## Architecture

### Core Components

1. **Rules Engine** (`rules_engine.py`): Main rules processing logic
2. **Database Tables**: Rules storage and management
3. **Caching System**: Performance optimization
4. **Learning System**: Automatic rule generation

### Database Schema

#### Rules Table
```sql
CREATE TABLE rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    priority INT DEFAULT 50,
    keywords JSON NOT NULL,  -- Array of keywords to match
    main_category VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    frequency INT DEFAULT 0,  -- Usage count
    confidence DECIMAL(3,2) DEFAULT 0.95,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by ENUM('manual', 'auto_learned') DEFAULT 'manual'
);
```

#### Salary Rules Table
```sql
CREATE TABLE salary_rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(50) NOT NULL,
    employee_names JSON NOT NULL,  -- Array of employee names
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## Rule Types

### 1. Manual Rules
- Created by administrators
- High priority (10-40)
- Cover common business patterns
- Examples: Vendor names, specific keywords

### 2. Auto-Learned Rules
- Generated from manual categorizations
- Medium priority (50)
- Learn from user behavior
- Examples: New vendor patterns, transaction descriptions

## Rule Processing Flow

### 1. Rule Loading
```python
def _load_rules(self):
    """Load rules from database and cache them."""
    # Query active rules ordered by priority
    # Cache in memory for performance
    # Set cache timestamp
```

### 2. Rule Matching
```python
def apply_rules(self, narration: str) -> Tuple[str, str, str]:
    """Apply rules to categorize transaction."""
    # 1. Check salary rules (highest priority)
    # 2. Check keyword rules (by priority)
    # 3. Return (main_category, sub_category, rule_name)
```

### 3. Rule Learning
```python
def learn_new_rules(self, transactions: List[Dict]) -> Dict:
    """Learn new rules from manual categorizations."""
    # 1. Group transactions by description
    # 2. Extract keywords
    # 3. Create new rules
    # 4. Store in database
```

## Rule Priority System

### Priority Levels
- **10-20**: Critical business rules (vendors, specific patterns)
- **30-40**: General business rules (categories, common patterns)
- **50**: Auto-learned rules (medium priority)
- **60+**: Fallback rules (low priority)

### Rule Selection
Rules are processed in priority order. The first matching rule wins.

## Keyword Matching

### JSON Keywords Format
```json
{
  "keywords": ["SWIGGY", "INSTAMART", "FOOD"]
}
```

### Matching Logic
- Case-insensitive matching
- Partial word matching
- Multiple keywords (ANY match)
- Exclusion keywords (NOT match) - future feature

## Salary Detection

### Employee Name Mapping
```json
{
  "team_name": "Operations Team",
  "employee_names": [
    "ARJUN DR EMP",
    "BALAJI GR",
    "GARIKAPATI PRADEEP"
  ]
}
```

### Salary Keywords
- "SALARY", "EXPENSES", "NEFT DR", "IMPS", "TPT"
- Must match employee name AND salary keyword

## Performance Optimization

### Caching System
- **Cache TTL**: 5 minutes
- **Thread-safe**: Uses locks for concurrent access
- **Auto-refresh**: Invalidates on rule updates

### Database Indexes
```sql
-- Performance indexes
CREATE INDEX idx_priority ON rules (priority);
CREATE INDEX idx_main_category ON rules (main_category);
CREATE INDEX idx_active ON rules (is_active);
CREATE INDEX idx_keywords ON rules ((CAST(keywords AS CHAR(1000) ARRAY)));
```

### Query Optimization
- Rules loaded once and cached
- Frequency updates in background threads
- Batch operations for rule learning

## Rule Learning Process

### 1. Detection Criteria
Transactions eligible for rule learning:
- `MainCategorySuggested` = "Uncategorized"
- `FinalMainCategory` = manually categorized
- `description` is not empty
- Minimum 2 occurrences

### 2. Keyword Extraction
```python
def _extract_keywords(self, text: str) -> List[str]:
    """Extract meaningful keywords from description."""
    # Filter out common words
    # Remove duplicates
    # Limit to 5 keywords
    # Check against existing rules
```

### 3. Rule Creation
```python
# New rule structure
{
    "name": "Auto-learned: SWIGGY +2",
    "priority": 50,
    "keywords": ["SWIGGY", "INSTAMART"],
    "main_category": "Office Overhead",
    "sub_category": "Swiggy",
    "frequency": 5,
    "confidence": 0.95,
    "created_by": "auto_learned"
}
```

### 4. Duplicate Prevention
- Check existing rules before creation
- Compare keywords and categories
- Prevent duplicate rule creation

## Rule Management

### Adding Manual Rules
```sql
INSERT INTO rules (name, priority, keywords, main_category, sub_category, created_by)
VALUES (
    'New Vendor Rule',
    10,
    '["VENDOR_NAME", "KEYWORD"]',
    'Grooming Inventory',
    'New Vendor',
    'manual'
);
```

### Updating Rules
```sql
UPDATE rules 
SET keywords = '["UPDATED", "KEYWORDS"]',
    priority = 15
WHERE name = 'Rule Name';
```

### Deactivating Rules
```sql
UPDATE rules 
SET is_active = FALSE 
WHERE name = 'Rule Name';
```

### Viewing Rule Statistics
```sql
SELECT 
    name,
    priority,
    main_category,
    sub_category,
    frequency,
    confidence,
    created_by,
    created_at
FROM rules 
WHERE is_active = TRUE 
ORDER BY priority, frequency DESC;
```

## Monitoring and Analytics

### Rule Statistics
- Total rules count
- Manual vs auto-learned breakdown
- Frequency tracking
- Confidence scores

### Performance Metrics
- Cache hit rate
- Rule processing time
- Learning success rate
- Database query performance

### Health Checks
- Database connectivity
- Rules cache status
- Learning system status
- Error rates

## Troubleshooting

### Common Issues

#### 1. Rules Not Loading
- Check database connectivity
- Verify rule table exists
- Check cache status
- Review error logs

#### 2. Poor Categorization
- Review rule priorities
- Check keyword matching
- Analyze learning patterns
- Update manual rules

#### 3. Performance Issues
- Check cache TTL
- Review database indexes
- Monitor query performance
- Optimize rule complexity

#### 4. Learning Not Working
- Check transaction data quality
- Verify learning criteria
- Review keyword extraction
- Check database permissions

### Debug Commands

#### Check Rules Cache
```python
rules_engine = get_rules_engine()
print(f"Rules loaded: {len(rules_engine.rules_cache)}")
print(f"Cache valid: {rules_engine._is_cache_valid()}")
```

#### Test Rule Matching
```python
result = apply_rules("UPI-MR-SWIGGY-123456")
print(f"Result: {result}")
```

#### Force Cache Refresh
```python
rules_engine.refresh_cache()
```

## Best Practices

### Rule Design
1. **Use specific keywords**: Avoid generic terms
2. **Set appropriate priorities**: Critical rules first
3. **Test thoroughly**: Verify rule accuracy
4. **Monitor performance**: Track rule effectiveness

### Learning System
1. **Quality data**: Ensure accurate manual categorizations
2. **Regular review**: Check auto-learned rules
3. **Clean up**: Remove ineffective rules
4. **Monitor growth**: Prevent rule explosion

### Performance
1. **Index optimization**: Use proper database indexes
2. **Cache management**: Monitor cache hit rates
3. **Query optimization**: Minimize database calls
4. **Resource monitoring**: Track memory and CPU usage

## Future Enhancements

### Planned Features
1. **Exclusion keywords**: NOT matching
2. **Rule confidence scoring**: Dynamic confidence
3. **Rule versioning**: Track rule changes
4. **A/B testing**: Compare rule effectiveness
5. **Machine learning integration**: ML-assisted rule creation

### Advanced Learning
1. **Pattern recognition**: Detect complex patterns
2. **Context awareness**: Consider transaction context
3. **Temporal patterns**: Time-based rule learning
4. **Cross-reference learning**: Learn from similar businesses

## API Integration

### Rule Management Endpoints
- `GET /rule-stats` - Get rule statistics
- `POST /refresh-rules` - Refresh rules cache
- `POST /sync` - Trigger rule learning

### Example Usage
```python
# Get rule statistics
stats = requests.get('/rule-stats', headers={'X-API-Key': key})

# Refresh rules cache
requests.post('/refresh-rules', headers={'X-API-Key': key})

# Trigger learning (via sync)
requests.post('/sync', json={'rows': transactions}, headers={'X-API-Key': key})
```

This rules system provides a robust, scalable, and intelligent foundation for transaction categorization that continuously improves through user interaction and machine learning.
