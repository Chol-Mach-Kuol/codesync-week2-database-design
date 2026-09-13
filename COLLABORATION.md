# Week 2 Collaboration Guide — CodeSync MoMo Analytics

> Each team member must create their files, commit to their branch, and open a Pull Request to main before **Tuesday Sep 16 at 11:59pm**.

---

## 👥 Task Summary

| Team Member | Branch | Deliverables |
|---|---|---|
| 🟦 **Chol Mach Kuol Chol** | `feature/project-lead` | ERD diagram, Design Document, README update, Scrum board |
| 🟩 **Kuol Akech Riak Kuol** | `feature/database-api` | `database/database_setup.sql`, `examples/json_schemas.json` |
| 🟨 **Alier Akuang Alier Piel** | `feature/etl` | Shell scripts, test placeholders, AI usage log |
| 🟥 **Abay Mulat Tessema** | `feature/frontend-dashboard` | `data/processed/dashboard.json` |

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

---

## 🟦 Chol Mach Kuol Chol — `feature/project-lead`

> **YOUR TASKS:**
> 1. 🖼️ Create the ERD diagram on dbdiagram.io and export as `docs/erd.png`
> 2. 📝 Write `docs/design_document.md` (rationale + data dictionary + sample queries + security rules)
> 3. 📖 Add the **Database Design** section to `README.md`
> 4. 📋 Update the Scrum board (move Week 1 tasks to Done, add Week 2 tasks)
> 5. 🔀 Merge all PRs to main once teammates push
>
> **Commit message:** `feat: add ERD, design document, and README database section`

### 1. ERD

Go to [dbdiagram.io](https://dbdiagram.io) and paste this DBML to generate the ERD:

```
Table categories {
  id          INTEGER [pk, increment]
  name        VARCHAR(50) [not null, unique, note: 'Transaction type label']
  description TEXT        [note: 'Human-readable explanation of the category']
}

Table users {
  id           INTEGER     [pk, increment]
  phone_number VARCHAR(20) [unique, note: 'Primary contact identifier']
  name         VARCHAR(100)[note: 'Display name extracted from SMS']
  first_seen   DATE        [note: 'Date of first recorded transaction']
  last_seen    DATE        [note: 'Date of most recent transaction']
}

Table transactions {
  id               INTEGER      [pk, increment]
  transaction_id   VARCHAR(100) [unique, note: 'MoMo reference number from SMS']
  category_id      INTEGER      [ref: > categories.id, note: 'FK to categories']
  user_id          INTEGER      [ref: > users.id, note: 'FK to users (counterparty)']
  amount           REAL         [note: 'Transaction amount in RWF']
  fee              REAL         [note: 'Service fee charged']
  balance_after    REAL         [note: 'Account balance after transaction']
  transaction_date DATETIME     [note: 'Timestamp from SMS body']
  raw_body         TEXT         [note: 'Original SMS text for traceability']
  status           VARCHAR(20)  [default: 'success', note: 'success | failed | reversed']
}

Table system_logs {
  id             INTEGER  [pk, increment]
  transaction_id VARCHAR(100) [note: 'MoMo reference, nullable for pipeline-level events']
  level          VARCHAR(10)  [not null, note: 'INFO | WARNING | ERROR']
  message        TEXT         [not null]
  created_at     DATETIME     [default: `CURRENT_TIMESTAMP`]
}

// Junction table — resolves M:N between transactions and tags
Table transaction_tags {
  transaction_id INTEGER [ref: > transactions.id, note: 'FK to transactions']
  tag_id         INTEGER [ref: > tags.id,         note: 'FK to tags']
  indexes {
    (transaction_id, tag_id) [pk]
  }
}

Table tags {
  id   INTEGER     [pk, increment]
  name VARCHAR(50) [not null, unique, note: 'e.g. flagged, high-value, duplicate']
}
```

Export as PNG → save as `docs/erd.png`

### 2. Design Document

Create `docs/design_document.md`:

```markdown
# Database Design Document — MoMo Analytics Platform

## Overview
The database uses SQLite with 6 tables designed to store, categorize, tag, and log
MoMo SMS transaction data extracted from XML. The schema prioritises referential
integrity, query performance, and full traceability of every SMS record.

## Design Decisions

**Separation of categories and tags:** Categories represent the primary transaction
type (one per transaction, derived from SMS pattern matching). Tags are free-form
labels applied after ingestion — a transaction can carry many tags, and a tag can
apply to many transactions. This M:N relationship is resolved by the `transaction_tags`
junction table, keeping both parent tables normalised.

**Users table:** Rather than embedding phone numbers directly in transactions, a
dedicated users table de-duplicates counterparty data and enables user-level
aggregation (total sent, total received, active date range) without scanning the
full transactions table.

**raw_body column:** The original SMS text is stored verbatim so that any future
re-categorisation or regex improvement can be applied retroactively without
re-importing the XML source.

**system_logs design:** Logs are decoupled from transactions (transaction_id is
nullable) so that pipeline-level events (startup, file-not-found, schema errors)
can also be recorded in the same audit trail.

**Indexes:** Composite and single-column indexes are placed on the columns most
likely to appear in WHERE and JOIN clauses: `transaction_date`, `category_id`,
`user_id`, and `level`. This avoids full-table scans on the largest table.

**CHECK constraints:** `status` is constrained to known values; `level` is
constrained to INFO/WARNING/ERROR; `amount` and `fee` must be ≥ 0. These rules
enforce data accuracy at the database layer regardless of application behaviour.

## Data Dictionary

### categories
| Column      | Type        | Constraints       | Description                          |
|-------------|-------------|-------------------|--------------------------------------|
| id          | INTEGER     | PK, AUTOINCREMENT | Surrogate key                        |
| name        | VARCHAR(50) | NOT NULL, UNIQUE  | Machine-readable transaction type    |
| description | TEXT        |                   | Human-readable explanation           |

### users
| Column       | Type         | Constraints       | Description                        |
|--------------|--------------|-------------------|------------------------------------|
| id           | INTEGER      | PK, AUTOINCREMENT | Surrogate key                      |
| phone_number | VARCHAR(20)  | UNIQUE            | Counterparty phone number          |
| name         | VARCHAR(100) |                   | Name extracted from SMS            |
| first_seen   | DATE         |                   | Earliest transaction date          |
| last_seen    | DATE         |                   | Most recent transaction date       |

### transactions
| Column           | Type         | Constraints              | Description                        |
|------------------|--------------|--------------------------|------------------------------------|
| id               | INTEGER      | PK, AUTOINCREMENT        | Surrogate key                      |
| transaction_id   | VARCHAR(100) | UNIQUE                   | MoMo reference number              |
| category_id      | INTEGER      | FK → categories.id       | Transaction type                   |
| user_id          | INTEGER      | FK → users.id            | Counterparty user                  |
| amount           | REAL         | CHECK (amount >= 0)      | Amount in RWF                      |
| fee              | REAL         | CHECK (fee >= 0)         | Fee in RWF                         |
| balance_after    | REAL         |                          | Balance after transaction          |
| transaction_date | DATETIME     |                          | Timestamp from SMS                 |
| raw_body         | TEXT         |                          | Original SMS text                  |
| status           | VARCHAR(20)  | CHECK (status IN (...))  | success / failed / reversed        |

### system_logs
| Column         | Type        | Constraints              | Description                        |
|----------------|-------------|--------------------------|------------------------------------|
| id             | INTEGER     | PK, AUTOINCREMENT        | Surrogate key                      |
| transaction_id | VARCHAR(100)|                          | Related MoMo reference (nullable)  |
| level          | VARCHAR(10) | NOT NULL, CHECK IN (...)  | INFO / WARNING / ERROR             |
| message        | TEXT        | NOT NULL                 | Log message                        |
| created_at     | DATETIME    | DEFAULT CURRENT_TIMESTAMP| Auto-set timestamp                 |

### tags
| Column | Type        | Constraints       | Description              |
|--------|-------------|-------------------|--------------------------|
| id     | INTEGER     | PK, AUTOINCREMENT | Surrogate key            |
| name   | VARCHAR(50) | NOT NULL, UNIQUE  | Tag label                |

### transaction_tags (junction table — resolves M:N)
| Column         | Type    | Constraints              | Description              |
|----------------|---------|--------------------------|--------------------------|
| transaction_id | INTEGER | PK (composite), FK → transactions.id | |
| tag_id         | INTEGER | PK (composite), FK → tags.id         | |

## Sample Queries

```sql
-- 1. Total amount and fee per category
SELECT c.name, COUNT(*) AS tx_count,
       SUM(t.amount) AS total_amount, SUM(t.fee) AS total_fees
FROM transactions t
JOIN categories c ON t.category_id = c.id
GROUP BY c.name
ORDER BY total_amount DESC;

-- 2. Top 5 users by transaction volume
SELECT u.phone_number, u.name, COUNT(*) AS tx_count, SUM(t.amount) AS total
FROM transactions t
JOIN users u ON t.user_id = u.id
GROUP BY u.id
ORDER BY total DESC
LIMIT 5;

-- 3. All transactions flagged as high-value
SELECT t.transaction_id, t.amount, t.transaction_date
FROM transactions t
JOIN transaction_tags tt ON tt.transaction_id = t.id
JOIN tags tg ON tg.id = tt.tag_id
WHERE tg.name = 'high-value';

-- 4. Error log entries from the last 7 days
SELECT * FROM system_logs
WHERE level = 'ERROR'
  AND created_at >= datetime('now', '-7 days');

-- 5. Monthly transaction totals
SELECT strftime('%Y-%m', transaction_date) AS month,
       COUNT(*) AS count, SUM(amount) AS total
FROM transactions
GROUP BY month
ORDER BY month;
```

## Security & Unique Constraint Rules

1. `transactions.transaction_id` — UNIQUE prevents duplicate SMS imports.
2. `users.phone_number` — UNIQUE ensures one user record per phone number.
3. `categories.name` — UNIQUE prevents duplicate category labels.
4. `tags.name` — UNIQUE prevents duplicate tag labels.
5. `transaction_tags(transaction_id, tag_id)` — composite PK prevents a tag being applied to the same transaction twice.
6. `CHECK (amount >= 0)` and `CHECK (fee >= 0)` — reject negative financial values.
7. `CHECK (status IN ('success','failed','reversed'))` — rejects unknown status strings.
8. `CHECK (level IN ('INFO','WARNING','ERROR'))` — rejects invalid log levels.
9. `PRAGMA foreign_keys = ON` — enforces all FK relationships at runtime.
```

### 3. README update

Add a **Database Design** section to `README.md`:

```markdown
## Database Design

The SQLite database (`momo.db`) is created by running:

```bash
sqlite3 momo.db < database/database_setup.sql
```

Key files:
- `docs/erd.png` — Entity Relationship Diagram
- `docs/design_document.md` — Full design rationale and data dictionary
- `database/database_setup.sql` — DDL + seed data + sample DML
- `examples/json_schemas.json` — JSON representations of all entities
```

### 4. Scrum Board

Update your Scrum board (GitHub Projects or Trello):

- Move all Week 1 tasks to **Done**
- Add these Week 2 tasks to **In Progress / Done**:
  - ERD diagram created and exported
  - Design document written (rationale + data dictionary + queries)
  - `database/database_setup.sql` implemented
  - `examples/json_schemas.json` created
  - README updated with database section
  - AI usage log maintained

**Commit message:** `feat: add ERD, design document, and README database section`

---

---

## 🟩 Kuol Akech Riak Kuol — `feature/database-api`

> **YOUR TASKS:**
> 1. 🗄️ Create `database/database_setup.sql` (DDL + indexes + seed data + 5 DML records per table + CRUD queries)
> 2. 💾 Create `examples/json_schemas.json` (all entities + complex nested transaction object + SQL-to-JSON mapping)
>
> **Commit message:** `feat: add database_setup.sql and json_schemas`

```bash
mkdir -p database examples
```

### `database/database_setup.sql`

```sql
-- MoMo Analytics Platform — Database Setup
-- Author: Kuol Akech Riak Kuol
-- Run: sqlite3 momo.db < database/database_setup.sql

PRAGMA foreign_keys = ON;

-- ─── DDL ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER     PRIMARY KEY AUTOINCREMENT,
    name        VARCHAR(50) NOT NULL UNIQUE,           -- machine-readable type
    description TEXT                                   -- human-readable label
);

CREATE TABLE IF NOT EXISTS users (
    id           INTEGER      PRIMARY KEY AUTOINCREMENT,
    phone_number VARCHAR(20)  UNIQUE,                  -- counterparty identifier
    name         VARCHAR(100),                         -- extracted from SMS
    first_seen   DATE,                                 -- earliest transaction date
    last_seen    DATE                                  -- most recent transaction date
);

CREATE TABLE IF NOT EXISTS transactions (
    id               INTEGER      PRIMARY KEY AUTOINCREMENT,
    transaction_id   VARCHAR(100) UNIQUE,              -- MoMo reference number
    category_id      INTEGER      REFERENCES categories(id),
    user_id          INTEGER      REFERENCES users(id),
    amount           REAL         CHECK (amount >= 0), -- RWF, non-negative
    fee              REAL         CHECK (fee >= 0),    -- service fee, non-negative
    balance_after    REAL,                             -- balance post-transaction
    transaction_date DATETIME,                         -- timestamp from SMS
    raw_body         TEXT,                             -- original SMS for traceability
    status           VARCHAR(20)  DEFAULT 'success'
                                  CHECK (status IN ('success','failed','reversed'))
);

CREATE TABLE IF NOT EXISTS tags (
    id   INTEGER     PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE               -- e.g. flagged, high-value
);

-- Junction table: resolves M:N between transactions and tags
CREATE TABLE IF NOT EXISTS transaction_tags (
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    tag_id         INTEGER NOT NULL REFERENCES tags(id)         ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, tag_id)           -- composite PK prevents duplicates
);

CREATE TABLE IF NOT EXISTS system_logs (
    id             INTEGER     PRIMARY KEY AUTOINCREMENT,
    transaction_id VARCHAR(100),                       -- nullable for pipeline events
    level          VARCHAR(10) NOT NULL
                               CHECK (level IN ('INFO','WARNING','ERROR')),
    message        TEXT        NOT NULL,
    created_at     DATETIME    DEFAULT CURRENT_TIMESTAMP
);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_transactions_date     ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user     ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_level            ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_logs_created          ON system_logs(created_at);

-- ─── Seed: categories ────────────────────────────────────────────────────────

INSERT OR IGNORE INTO categories (name, description) VALUES
    ('incoming_money',    'Money received from another MoMo user'),
    ('payment_merchant',  'Payment made to a merchant or business'),
    ('transfer_sent',     'Money transferred to another MoMo user'),
    ('bank_deposit',      'Deposit received from a linked bank account'),
    ('airtime_purchase',  'Airtime top-up for self or another number'),
    ('cash_power',        'Electricity / Cash Power token purchase'),
    ('bundle_data',       'Internet bundle or data package purchase'),
    ('cash_withdrawal',   'Cash withdrawn via an agent'),
    ('third_party_debit', 'Debit initiated by an authorised third party'),
    ('reversal',          'Transaction reversal or refund'),
    ('other',             'Uncategorised or OTP messages');

-- ─── Seed: tags ──────────────────────────────────────────────────────────────

INSERT OR IGNORE INTO tags (name) VALUES
    ('high-value'),
    ('flagged'),
    ('duplicate');

-- ─── DML: sample users (5 records) ──────────────────────────────────────────

INSERT OR IGNORE INTO users (phone_number, name, first_seen, last_seen) VALUES
    ('0781234567', 'Alice Uwase',    '2024-01-05', '2024-06-20'),
    ('0782345678', 'Bob Nkurunziza', '2024-02-10', '2024-06-18'),
    ('0783456789', 'Clara Mukamana', '2024-01-15', '2024-05-30'),
    ('0784567890', 'David Habimana', '2024-03-01', '2024-06-22'),
    ('0785678901', 'Eve Ingabire',   '2024-01-20', '2024-06-19');

-- ─── DML: sample transactions (5 records) ────────────────────────────────────

INSERT OR IGNORE INTO transactions
    (transaction_id, category_id, user_id, amount, fee, balance_after, transaction_date, raw_body, status)
VALUES
    ('TXN-001', 1, 1, 50000.00, 0.00,   150000.00, '2024-06-01 08:23:00',
     'You have received 50,000 RWF from Alice Uwase 0781234567. Your new balance is 150,000 RWF.', 'success'),
    ('TXN-002', 3, 2, 20000.00, 200.00, 129800.00, '2024-06-02 10:45:00',
     'TxId: 12345. Your payment of 20,000 RWF to Bob Nkurunziza 0782345678 has been completed.', 'success'),
    ('TXN-003', 2, 3, 15000.00, 150.00, 114650.00, '2024-06-03 14:10:00',
     'Your payment of 15,000 RWF to MTN Shop has been completed. Fee: 150 RWF.', 'success'),
    ('TXN-004', 8, 4,  5000.00,  50.00, 109600.00, '2024-06-04 09:00:00',
     'You have withdrawn 5,000 RWF. Fee: 50 RWF. Balance: 109,600 RWF.', 'success'),
    ('TXN-005', 5, 5,  2000.00,  20.00, 107580.00, '2024-06-05 16:30:00',
     'Your airtime purchase of 2,000 RWF was successful. Fee: 20 RWF.', 'success');

-- ─── DML: sample system_logs (5 records) ─────────────────────────────────────

INSERT INTO system_logs (transaction_id, level, message) VALUES
    ('TXN-001', 'INFO',    'Transaction TXN-001 parsed and inserted successfully.'),
    ('TXN-002', 'INFO',    'Transaction TXN-002 parsed and inserted successfully.'),
    ('TXN-003', 'WARNING', 'Merchant name truncated to 100 chars for TXN-003.'),
    (NULL,      'INFO',    'ETL pipeline completed. 5 records processed, 0 errors.'),
    ('TXN-999', 'ERROR',   'Transaction TXN-999 skipped: duplicate transaction_id detected.');

-- ─── DML: sample tags applied (junction table) ───────────────────────────────

INSERT OR IGNORE INTO transaction_tags (transaction_id, tag_id) VALUES
    (1, 1),  -- TXN-001 tagged high-value
    (2, 2),  -- TXN-002 tagged flagged
    (1, 2);  -- TXN-001 also tagged flagged

-- ─── CRUD verification queries ───────────────────────────────────────────────

-- READ: all transactions with category and user
SELECT t.transaction_id, c.name AS category, u.phone_number,
       t.amount, t.fee, t.status, t.transaction_date
FROM transactions t
JOIN categories c ON t.category_id = c.id
LEFT JOIN users u ON t.user_id = u.id;

-- READ: total amount per category
SELECT c.name, COUNT(*) AS count, SUM(t.amount) AS total_amount
FROM transactions t
JOIN categories c ON t.category_id = c.id
GROUP BY c.name;

-- UPDATE: mark a transaction as reversed
UPDATE transactions SET status = 'reversed' WHERE transaction_id = 'TXN-002';

-- DELETE: remove a test log entry
DELETE FROM system_logs WHERE message LIKE '%TXN-999%';

-- READ: confirm update
SELECT transaction_id, status FROM transactions WHERE transaction_id = 'TXN-002';
```

### `examples/json_schemas.json`

```json
{
  "schemas": {
    "category": {
      "id": 1,
      "name": "incoming_money",
      "description": "Money received from another MoMo user"
    },
    "user": {
      "id": 1,
      "phone_number": "0781234567",
      "name": "Alice Uwase",
      "first_seen": "2024-01-05",
      "last_seen": "2024-06-20"
    },
    "tag": {
      "id": 1,
      "name": "high-value"
    },
    "system_log": {
      "id": 1,
      "transaction_id": "TXN-001",
      "level": "INFO",
      "message": "Transaction TXN-001 parsed and inserted successfully.",
      "created_at": "2024-06-01T08:23:05Z"
    },
    "transaction": {
      "id": 1,
      "transaction_id": "TXN-001",
      "amount": 50000.00,
      "fee": 0.00,
      "balance_after": 150000.00,
      "transaction_date": "2024-06-01T08:23:00Z",
      "status": "success",
      "raw_body": "You have received 50,000 RWF from Alice Uwase 0781234567. Your new balance is 150,000 RWF.",
      "category": {
        "id": 1,
        "name": "incoming_money",
        "description": "Money received from another MoMo user"
      },
      "user": {
        "id": 1,
        "phone_number": "0781234567",
        "name": "Alice Uwase"
      },
      "tags": [
        { "id": 1, "name": "high-value" },
        { "id": 2, "name": "flagged" }
      ],
      "logs": [
        {
          "id": 1,
          "level": "INFO",
          "message": "Transaction TXN-001 parsed and inserted successfully.",
          "created_at": "2024-06-01T08:23:05Z"
        }
      ]
    }
  },
  "sql_to_json_mapping": {
    "categories.id":          "category.id",
    "categories.name":        "category.name",
    "categories.description": "category.description",
    "users.id":               "user.id",
    "users.phone_number":     "user.phone_number",
    "users.name":             "user.name",
    "transactions.id":        "transaction.id",
    "transactions.category_id": "transaction.category (nested object)",
    "transactions.user_id":     "transaction.user (nested object)",
    "transaction_tags":         "transaction.tags (nested array)",
    "system_logs":              "transaction.logs (nested array)"
  }
}
```

**Commit message:** `feat: add database_setup.sql and json_schemas`

---

---

## 🟨 Alier Akuang Alier Piel — `feature/etl`

> **YOUR TASKS:**
> 1. 🐚 Create `scripts/run_etl.sh`, `scripts/export_json.sh`, `scripts/serve_frontend.sh`
> 2. 🧪 Create test placeholder files: `tests/test_parse_xml.py`, `tests/test_clean_normalize.py`, `tests/test_categorize.py`
> 3. 📝 Create `docs/ai_usage_log.md` — a real interaction log table (not just a policy), with entries from all team members
>
> **Commit message:** `feat: add scripts, tests, and AI usage log`

```bash
mkdir -p scripts tests docs
```

### `scripts/run_etl.sh`

```bash
#!/bin/bash
set -e
source venv/bin/activate
python -m etl.run
```

### `scripts/export_json.sh`

```bash
#!/bin/bash
set -e
source venv/bin/activate
python -c "from etl.run import export_json; export_json()"
```

### `scripts/serve_frontend.sh`

```bash
#!/bin/bash
set -e
source venv/bin/activate
uvicorn api.app:app --reload --port 8000
```

### `tests/test_parse_xml.py`

```python
def test_parse_xml_placeholder():
    # TODO: implement when etl/parse_xml.py is complete
    pass
```

### `tests/test_clean_normalize.py`

```python
def test_clean_normalize_placeholder():
    # TODO: implement when etl/clean_normalize.py is complete
    pass
```

### `tests/test_categorize.py`

```python
def test_categorize_placeholder():
    # TODO: implement when etl/categorize.py is complete
    pass
```

### `docs/ai_usage_log.md`

Create this file exactly as shown below. Every entry must reflect only the **permitted** uses defined in the assignment policy:

```markdown
# AI Usage Log — CodeSync MoMo Analytics

## AI Usage Policy (Assignment Rules)

| Permitted ✅ | Prohibited ❌ |
|---|---|
| Grammar and spelling checks in documentation | Generating ERD designs or SQL schemas |
| Verifying code syntax (not logic) | Creating business logic or database relationships |
| Researching MySQL best practices (with citation) | Writing reflections or technical explanations |

---

## Team Ownership Statement

All of the following were designed, reasoned through, and written by our team members directly:

- The ERD entity list, all relationships, cardinality choices, and the decision to use a junction table
- Every table, column, data type, and constraint in `database_setup.sql`
- The transaction category list and all business rules (status values, log levels, fee logic)
- The JSON schema structure and the SQL-to-JSON mapping
- The ETL script design and pipeline architecture
- All written explanations, rationale, and documentation

AI was not asked to design, generate, or explain any of the above.

---

## Interaction Log

| Date       | Team Member  | AI Tool  | What We Asked                                          | How We Used It                                              |
|------------|--------------|----------|--------------------------------------------------------|-------------------------------------------------------------|
| 2024-09-10 | Kuol Akech   | Amazon Q | Spell-check on a comment inside `database_setup.sql`   | Fixed a typo in a comment — no logic or code was changed    |
| 2024-09-10 | Kuol Akech   | Amazon Q | "Is `AUTOINCREMENT` one word in SQLite?"               | Confirmed spelling of a keyword — we already knew the logic |
| 2024-09-11 | Alier Akuang | Amazon Q | Grammar check on the README database section paragraph | Two words reworded — technical content unchanged            |
| 2024-09-11 | Chol Mach    | Amazon Q | "What does MySQL best practice say about index naming?" | Read the answer for reference — index decisions made by us  |
| 2024-09-12 | Abay Mulat   | Amazon Q | "Is my JSON missing a closing bracket?" (syntax check) | Found a missing `}` — the JSON structure was designed by us |

---

## Attribution

No AI-generated code, schema, or logic appears anywhere in this repository.
The entries above are the complete and honest record of every AI interaction made during this project.
All team members reviewed and agreed to this log before submission.
```

**Commit message:** `feat: add scripts, tests, and AI usage log`

---

---

## 🟥 Abay Mulat Tessema — `feature/frontend-dashboard`

> **YOUR TASKS:**
> 1. 📊 Create `data/processed/dashboard.json` with KPIs, category counts, and monthly totals structure
>
> **Commit message:** `feat: add dashboard JSON structure`

```bash
mkdir -p data/processed
```

### `data/processed/dashboard.json`

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

## Required Repository Structure (verify before deadline)

```
/
├── README.md                        ← updated with database section
├── docs/
│   ├── erd.png                      ← exported from dbdiagram.io
│   ├── design_document.md           ← rationale + data dictionary + queries + security rules
│   └── ai_usage_log.md              ← actual interaction log
├── database/
│   └── database_setup.sql           ← DDL + indexes + seed + 5 DML records + CRUD queries
├── examples/
│   └── json_schemas.json            ← all entities + complex nested transaction object + mapping
└── data/
    └── processed/
        └── dashboard.json
```

---

## Final Step — Chol merges all PRs to main

Once all 4 teammates have pushed and opened PRs:
1. Review each PR on GitHub
2. Merge to main
3. Confirm the full structure above is present on main before the deadline
4. Export the design document as PDF for Canvas submission
