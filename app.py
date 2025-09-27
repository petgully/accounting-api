from fastapi import FastAPI, Depends, Header, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Tuple
import os, re, hashlib
import joblib

# ---------- FastAPI ----------
app = FastAPI(title="Accounting API", version="2.0.0", description="Database-driven transaction categorization system")

# ---------- Security ----------
API_KEY = os.getenv("API_KEY", "")
if not API_KEY:
    raise ValueError("API_KEY environment variable is required")

def require_key(x_api_key: str = Header(default="")):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

# ---------- Optional OpenAI for subcategory fallback ----------
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

try:
    import openai
    if OPENAI_API_KEY:
        openai.api_key = OPENAI_API_KEY
except Exception:
    openai = None

# ---------- MySQL ----------
import mysql.connector

DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_NAME = os.getenv("DB_NAME")

if not all([DB_HOST, DB_USER, DB_PASS, DB_NAME]):
    raise ValueError("Database environment variables (DB_HOST, DB_USER, DB_PASS, DB_NAME) are required")

def get_conn():
    return mysql.connector.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME
    )

# ---------- Rules Engine ----------
from rules_engine import get_rules_engine, apply_rules

# ---------- ML artifacts (optional) ----------
MODEL = None
VECT = None
ML_THRESHOLD = float(os.getenv("ML_THRESHOLD", "0.75"))

def load_model():
    global MODEL, VECT
    try:
        VECT = joblib.load("model/tfidf.joblib")
        MODEL = joblib.load("model/logreg.joblib")
        print("ML model loaded.")
    except Exception as e:
        print(f"ML model not loaded: {e}")

load_model()

# ---------- Schemas ----------
class RowIn(BaseModel):
    row_index: Optional[int] = None
    date: str
    description: str
    amount: float
    balance: Optional[float] = None
    account: Optional[str] = ""
    currency: Optional[str] = "INR"

class PredOut(RowIn):
    vendor: Optional[str] = ""
    rule_hit: Optional[str] = ""
    main_category_suggested: str
    sub_category_suggested: str
    confidence: float

class Rows(BaseModel):
    rows: List[RowIn]

class SyncRowIn(RowIn):
    vendor: Optional[str] = None
    main_category: Optional[str] = None
    sub_category: Optional[str] = None
    confidence: Optional[float] = None
    rule_hit: Optional[str] = None
    raw_row: Optional[int] = None

class SyncRows(BaseModel):
    rows: List[SyncRowIn]

class SyncResponse(BaseModel):
    success: bool
    published_count: int
    rules_created: int
    message: str

# ---------- Utils ----------
def normalize_desc(s: str) -> str:
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'[^A-Za-z0-9 &:/._-]', '', s)
    return s

def tx_hash(account: str, date: str, amount: float, norm_desc: str) -> str:
    return hashlib.sha256(f"{account}|{date}|{amount:.2f}|{norm_desc}".encode("utf-8")).hexdigest()

def ml_main_category(desc: str) -> Tuple[str, float]:
    if MODEL is None or VECT is None:
        return "Uncategorized", 0.0
    try:
        X = VECT.transform([desc])
        proba = MODEL.predict_proba(X)[0]
        idx = proba.argmax()
        label = MODEL.classes_[idx]
        conf = float(proba[idx])
        return label, conf
    except Exception:
        return "Uncategorized", 0.0

def llm_subcategory(desc: str, amount: float, main: str) -> str:
    if not (openai and OPENAI_API_KEY):
        return "Misc"

    prompt = f"""
You assign a short subcategory (2-5 words) for a business bank transaction.

Main category: {main}
Description: {desc}
Amount: {amount}

Rules:
- Be concise, noun-phrase style.
- Prefer consistent vendor-based labels if obvious.
- If unclear, return "Misc".

Only return the subcategory text, nothing else.
"""

    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[{"role":"user","content":prompt}],
            temperature=0.1
        )
        text = resp["choices"][0]["message"]["content"].strip()
        return text[:40] if text else "Misc"
    except Exception:
        return "Misc"

# ---------- Endpoints ----------
@app.get("/")
def root():
    return {
        "message": "Accounting API v2.0",
        "status": "running",
        "endpoints": {
            "classify": "/classify - Categorize transactions",
            "sync": "/sync - Store verified transactions and learn rules",
            "rule-stats": "/rule-stats - Get rule statistics",
            "health": "/health - Health check"
        }
    }

@app.get("/health")
def health_check():
    """Health check endpoint."""
    try:
        # Test database connection
        conn = get_conn()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        
        # Test rules engine
        rules_engine = get_rules_engine()
        stats = rules_engine.get_rule_statistics()
        
        return {
            "status": "healthy",
            "database": "connected",
            "rules_loaded": stats['total_rules'],
            "timestamp": str(datetime.now())
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": str(datetime.now())
        }

@app.post("/classify", response_model=List[PredOut], dependencies=[Depends(require_key)])
def classify(rows: Rows):
    """
    Categorize transactions using database-driven rules.
    """
    out: List[PredOut] = []
    
    for r in rows.rows:
        nd = normalize_desc(r.description)
        vendor = (nd.split(' ')[0][:40] if nd else "")

        # Apply database-driven rules first
        main, sub, rule = apply_rules(nd)
        conf = 0.95 if main else 0.0

        # ML fallback only if no rule matched
        if not main:
            pred, pconf = ml_main_category(nd)
            if pconf >= ML_THRESHOLD:
                main, conf = pred, pconf
            else:
                main, conf = "Uncategorized", pconf

        # Subcategory: use rule sub if provided, else LLM fallback
        sub_final = sub if sub else llm_subcategory(nd, r.amount, main)

        out.append(PredOut(
            row_index=r.row_index, 
            date=r.date, 
            description=r.description, 
            amount=r.amount,
            balance=r.balance, 
            account=r.account, 
            currency=r.currency,
            vendor=vendor, 
            rule_hit=rule or "",
            main_category_suggested=main, 
            sub_category_suggested=sub_final, 
            confidence=conf
        ))
    
    return out

@app.post("/sync", response_model=SyncResponse, dependencies=[Depends(require_key)])
def sync(rows: SyncRows):
    """
    Store verified transactions and learn new rules from manual categorizations.
    """
    conn = get_conn()
    cursor = conn.cursor()
    
    try:
        published_count = 0
        rules_created = 0
        
        # Prepare transactions for rule learning
        transactions_for_learning = []
        
        # Insert transactions
        ins_raw = """
        INSERT IGNORE INTO transactions_raw
        (hash, posted_at, description_raw, amount, balance_after, account, currency, created_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,NOW())
        """

        ins_can = """
        INSERT IGNORE INTO transactions_canonical
        (raw_hash, posted_at, normalized_desc, amount, debit_credit, vendor_text, main_category_id,
         sub_category_text, confidence, source, reviewed_at, rule_hit)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'sheet',NOW(),%s)
        """

        for r in rows.rows:
            nd = normalize_desc(r.description)
            h = tx_hash(r.account or "", r.date, r.amount, nd)

            # Insert raw transaction
            cursor.execute(ins_raw, (h, r.date, r.description, r.amount, r.balance, r.account, r.currency))

            # Get main category ID
            main_id = None
            if r.main_category:
                cursor.execute("SELECT id FROM categories_main WHERE name=%s", (r.main_category,))
                row = cursor.fetchone()
                if row:
                    main_id = row[0]

            debit_credit = 'debit' if r.amount < 0 else 'credit'
            
            # Insert canonical transaction
            cursor.execute(ins_can, (
                h, r.date, nd, r.amount, debit_credit,
                r.vendor, main_id, r.sub_category, 
                r.confidence if r.confidence is not None else 0.0,
                r.rule_hit
            ))
            
            published_count += 1
            
            # Prepare for rule learning if this was manually categorized
            if (r.main_category and r.sub_category and 
                r.main_category != "Uncategorized" and
                r.description):
                transactions_for_learning.append({
                    'description': r.description,
                    'main_category_suggested': 'Uncategorized',  # Was uncategorized initially
                    'main_category': r.main_category,
                    'sub_category': r.sub_category,
                    'confidence': r.confidence or 0.0
                })

        # Commit transaction insertions
        conn.commit()
        
        # Learn new rules from manual categorizations
        if transactions_for_learning:
            rules_engine = get_rules_engine()
            learning_result = rules_engine.learn_new_rules(transactions_for_learning)
            
            if learning_result['success']:
                rules_created = learning_result['rules_created']
        
        # Prepare response message
        message_parts = [f"Successfully published {published_count} transactions"]
        if rules_created > 0:
            message_parts.append(f"and learned {rules_created} new rules")
        else:
            message_parts.append("(no new rules learned)")
        
        return SyncResponse(
            success=True,
            published_count=published_count,
            rules_created=rules_created,
            message=" ".join(message_parts)
        )
        
    except Exception as e:
        conn.rollback()
        return SyncResponse(
            success=False,
            published_count=0,
            rules_created=0,
            message=f"Error: {str(e)}"
        )
    finally:
        cursor.close()
        conn.close()

@app.get("/rule-stats", dependencies=[Depends(require_key)])
def get_rule_stats():
    """
    Get statistics about current rules and database transactions.
    """
    try:
        rules_engine = get_rules_engine()
        stats = rules_engine.get_rule_statistics()
        
        return {
            "ok": True,
            "total_rules": stats['total_rules'],
            "auto_learned_rules": stats['auto_learned_rules'],
            "manual_rules": stats['manual_rules'],
            "database_stats": stats['database_stats'],
            "top_categories": stats['top_categories']
        }
        
    except Exception as e:
        return {
            "ok": False,
            "message": f"Error getting statistics: {str(e)}"
        }

@app.post("/refresh-rules", dependencies=[Depends(require_key)])
def refresh_rules():
    """
    Manually refresh the rules cache.
    """
    try:
        rules_engine = get_rules_engine()
        rules_engine.refresh_cache()
        
        stats = rules_engine.get_rule_statistics()
        
        return {
            "ok": True,
            "message": "Rules cache refreshed successfully",
            "total_rules": stats['total_rules']
        }
    except Exception as e:
        return {
            "ok": False,
            "message": f"Error refreshing rules: {str(e)}"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)