# Week 2 Collaboration Guide — CodeSync MoMo Analytics

> Each team member must create their files, commit to their branch, and open a Pull Request to main before **Tuesday Sep 16 at 11:59pm**.

---

## Git Workflow (Everyone)

```bash
# 1. Switch to your branch
git checkout <your-branch>

# 2. Sync with main
git pull origin main

# 3. Create your files (see your section below)

# 4. Stage, commit, and push
git add .
git commit -m "feat: <describe what you did>"
git push origin <your-branch>
```

Then open a Pull Request on GitHub from your branch → main.

---

## Chol Mach Kuol Chol — `feature/project-lead`

**Tasks:** ERD diagram + Design Document

1. Go to [dbdiagram.io](https://dbdiagram.io) and paste this DBML to generate the ERD:

```
Table categories {
  id INTEGER [pk, increment]
  name VARCHAR(50) [not null, unique]
  description TEXT
}

Table users {
  id INTEGER [pk, increment]
  phone_number VARCHAR(20) [unique]
  name VARCHAR(100)
  first_seen DATE
  last_seen DATE
}

Table transactions {
  id INTEGER [pk, increment]
  transaction_id VARCHAR(100) [unique]
  category_id INTEGER [ref: > categories.id]
  user_id INTEGER [ref: > users.id]
  amount REAL
  fee REAL
  balance_after REAL
  transaction_date DATETIME
  raw_body TEXT
  status VARCHAR(20)
}

Table system_logs {
  id INTEGER [pk, increment]
  transaction_id VARCHAR(100)
  level VARCHAR(10)
  message TEXT
  created_at DATETIME
}
```

2. Export as PNG → save as `docs/erd.png`
3. Create `docs/design_document.md` with the content below:

```markdown
# Database Design Document — MoMo Analytics Platform

## Overview
The database uses SQLite with 4 tables designed to store, categorize,
and log MoMo SMS transaction data extracted from XML.

## Tables

### categories
Stores the 11 transaction types identified from the MoMo XML data.
Seeded at schema creation. Used as a lookup table by transactions.

### users
Stores unique phone numbers and names extracted from transaction SMS bodies.
Tracks first and last seen dates to support user activity analysis.

### transactions
Core table. Each row is one MoMo transaction with amount, fee, balance,
date, category, associated user, and the original raw SMS body for traceability.

### system_logs
Records ETL pipeline events (INFO, WARNING, ERROR) linked to transaction IDs
for debugging and audit purposes. Invalid records are also written here
before being routed to the dead letter folder.

## Design Decisions
- Foreign keys enforced via PRAGMA foreign_keys = ON
- Indexes on transaction_date, category_id, user_id for query performance
- INSERT OR IGNORE used for category seeding to allow re-running the schema safely
- raw_body stored to preserve original SMS for debugging and re-categorization
```

**Commit message:** `feat: add ERD and design document`

---

## Kuol Akech Riak Kuol — `feature/database-api`

**Tasks:** SQL schema + JSON schemas

```bash
mkdir -p database/schemas
```

**`database/schema.sql`**
```sql
-- MoMo Analytics Platform — Database Schema
-- Author: Kuol Akech Riak Kuol

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE IF NOT EXISTS users (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    phone_number VARCHAR(20) UNIQUE,
    name         VARCHAR(100),
    first_seen   DATE,
    last_seen    DATE
);

CREATE TABLE IF NOT EXISTS transactions (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id   VARCHAR(100) UNIQUE,
    category_id      INTEGER REFERENCES categories(id),
    user_id          INTEGER REFERENCES users(id),
    amount           REAL,
    fee              REAL,
    balance_after    REAL,
    transaction_date DATETIME,
    raw_body         TEXT,
    status           VARCHAR(20) DEFAULT 'success'
);

CREATE TABLE IF NOT EXISTS system_logs (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id VARCHAR(100),
    level          VARCHAR(10) NOT NULL,
    message        TEXT        NOT NULL,
    created_at     DATETIME    DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_date     ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user     ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_level            ON system_logs(level);

-- Seed categories
INSERT OR IGNORE INTO categories (name, description) VALUES
    ('incoming_money',    'Money received from another MoMo user'),
    ('payment_merchant',  'Payment made to a merchant or business'),
    ('transfer_sent',     'Money transferred to another user (*165*S*)'),
    ('bank_deposit',      'Deposit from a bank account (*113*R*)'),
    ('airtime_purchase',  'Airtime top-up for self or others'),
    ('cash_power',        'Electricity/Cash Power token purchase'),
    ('bundle_data',       'Internet bundle or data purchase'),
    ('cash_withdrawal',   'Cash withdrawn via agent'),
    ('third_party_debit', 'Debit initiated by a third party (*164*S*)'),
    ('reversal',          'Transaction reversal or refund'),
    ('other',             'Uncategorized or OTP messages');
```

**`database/schemas/transactions.json`**
```json
{
  "table": "transactions",
  "fields": [
    { "name": "id",               "type": "integer", "primary_key": true },
    { "name": "transaction_id",   "type": "string",  "unique": true },
    { "name": "category_id",      "type": "integer", "foreign_key": "categories.id" },
    { "name": "user_id",          "type": "integer", "foreign_key": "users.id" },
    { "name": "amount",           "type": "number" },
    { "name": "fee",              "type": "number" },
    { "name": "balance_after",    "type": "number" },
    { "name": "transaction_date", "type": "string",  "format": "datetime" },
    { "name": "raw_body",         "type": "string" },
    { "name": "status",           "type": "string",  "default": "success" }
  ]
}
```

**`database/schemas/categories.json`**
```json
{
  "table": "categories",
  "fields": [
    { "name": "id",          "type": "integer", "primary_key": true },
    { "name": "name",        "type": "string",  "unique": true, "max_length": 50 },
    { "name": "description", "type": "string" }
  ]
}
```

**`database/schemas/users.json`**
```json
{
  "table": "users",
  "fields": [
    { "name": "id",           "type": "integer", "primary_key": true },
    { "name": "phone_number", "type": "string",  "unique": true, "max_length": 20 },
    { "name": "name",         "type": "string",  "max_length": 100 },
    { "name": "first_seen",   "type": "string",  "format": "date" },
    { "name": "last_seen",    "type": "string",  "format": "date" }
  ]
}
```

**`database/schemas/system_logs.json`**
```json
{
  "table": "system_logs",
  "fields": [
    { "name": "id",             "type": "integer", "primary_key": true },
    { "name": "transaction_id", "type": "string" },
    { "name": "level",          "type": "string",  "enum": ["INFO", "WARNING", "ERROR"] },
    { "name": "message",        "type": "string" },
    { "name": "created_at",     "type": "string",  "format": "datetime", "default": "CURRENT_TIMESTAMP" }
  ]
}
```

**Commit message:** `feat: add database schema and JSON schemas`

---

## Alier Akuang Alier Piel — `feature/etl`

**Tasks:** Shell scripts + test placeholders + AI usage policy

```bash
mkdir -p scripts
```

**`scripts/run_etl.sh`**
```bash
#!/bin/bash
set -e
source venv/bin/activate
python -m etl.run
```

**`scripts/export_json.sh`**
```bash
#!/bin/bash
set -e
source venv/bin/activate
python -c "from etl.run import export_json; export_json()"
```

**`scripts/serve_frontend.sh`**
```bash
#!/bin/bash
set -e
source venv/bin/activate
uvicorn api.app:app --reload --port 8000
```

**`tests/test_parse_xml.py`**
```python
def test_parse_xml_placeholder():
    # TODO: implement when etl/parse_xml.py is complete
    pass
```

**`tests/test_clean_normalize.py`**
```python
def test_clean_normalize_placeholder():
    # TODO: implement when etl/clean_normalize.py is complete
    pass
```

**`tests/test_categorize.py`**
```python
def test_categorize_placeholder():
    # TODO: implement when etl/categorize.py is complete
    pass
```

**`docs/ai_usage_policy.md`**
```markdown
# AI Usage Policy — CodeSync MoMo Analytics

## Tools Used
- Amazon Q Developer (AWS IDE plugin) — code generation, schema design, debugging assistance

## How AI Was Used
- Generating boilerplate SQL schema and JSON schema files
- Suggesting project structure and file organization
- Assisting with ETL pipeline design decisions
- Reviewing and explaining code snippets

## How AI Was NOT Used
- AI did not write final business logic autonomously
- All AI-generated code was reviewed and approved by the responsible team member before committing
- AI was not used to fabricate data or test results

## Team Acknowledgement
All team members understand that AI tools assist but do not replace understanding.
Each member is responsible for the code they commit.
```

**Commit message:** `feat: add scripts, tests, and AI usage policy`

---

## Abay Mulat Tessema — `feature/frontend-dashboard`

**Tasks:** Dashboard JSON structure

```bash
mkdir -p data/processed
```

**`data/processed/dashboard.json`**
```json
{
  "kpis": {
    "Total Transactions": 0,
    "Total Amount (RWF)": 0,
    "Total Fees (RWF)": 0,
    "Unique Users": 0
  },
  "categories": [
    { "name": "incoming_money",    "count": 0 },
    { "name": "payment_merchant",  "count": 0 },
    { "name": "transfer_sent",     "count": 0 },
    { "name": "bank_deposit",      "count": 0 },
    { "name": "airtime_purchase",  "count": 0 },
    { "name": "cash_power",        "count": 0 },
    { "name": "bundle_data",       "count": 0 },
    { "name": "cash_withdrawal",   "count": 0 },
    { "name": "third_party_debit", "count": 0 },
    { "name": "reversal",          "count": 0 },
    { "name": "other",             "count": 0 }
  ],
  "monthly_totals": []
}
```

**Commit message:** `feat: add dashboard JSON structure`

---

## Final Step — Chol merges all PRs to main

Once all 4 teammates have pushed and opened PRs:
1. Review each PR on GitHub
2. Merge to main
3. Confirm all files are present on main before the deadline
