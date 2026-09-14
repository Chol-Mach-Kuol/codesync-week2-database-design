-- =============================================================
-- MoMo SMS Analytics Platform — Database Setup
-- Project : CodeSync
-- Week    : 2 — Database Design and Implementation
-- Engine  : MySQL (InnoDB)
-- =============================================================

CREATE DATABASE IF NOT EXISTS momo
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE momo;

-- =============================================================
-- TABLE: categories
-- Lookup table for the 11 MoMo transaction types.
-- Seeded immediately after creation.
-- =============================================================
CREATE TABLE IF NOT EXISTS categories (
    id          INT           NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key',
    name        VARCHAR(50)   NOT NULL                COMMENT 'Machine-readable transaction type label',
    description TEXT                                  COMMENT 'Human-readable explanation of the category',
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLE: users
-- Unique counterparty phone numbers and names from SMS bodies.
-- =============================================================
CREATE TABLE IF NOT EXISTS users (
    id           INT          NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key',
    phone_number VARCHAR(20)           COMMENT 'Counterparty phone number',
    name         VARCHAR(100)          COMMENT 'Display name extracted from SMS',
    first_seen   DATE                  COMMENT 'Date of earliest recorded transaction',
    last_seen    DATE                  COMMENT 'Date of most recent transaction',
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_phone (phone_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLE: transactions
-- Core table — one row per MoMo SMS transaction.
-- =============================================================
CREATE TABLE IF NOT EXISTS transactions (
    id               INT           NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key',
    transaction_id   VARCHAR(100)           COMMENT 'MoMo reference number from SMS',
    category_id      INT                    COMMENT 'FK to categories.id — transaction type',
    user_id          INT                    COMMENT 'FK to users.id — counterparty user',
    amount           DECIMAL(15,2)          COMMENT 'Transaction amount in RWF',
    fee              DECIMAL(15,2)          COMMENT 'Service fee in RWF',
    balance_after    DECIMAL(15,2)          COMMENT 'Account balance after transaction',
    transaction_date DATETIME               COMMENT 'Timestamp parsed from SMS body',
    raw_body         TEXT                   COMMENT 'Original SMS text for traceability',
    status           VARCHAR(20)  NOT NULL DEFAULT 'success' COMMENT 'Transaction outcome: success | failed | reversed',
    PRIMARY KEY (id),
    UNIQUE KEY uq_transactions_txid (transaction_id),
    CONSTRAINT fk_tx_category FOREIGN KEY (category_id) REFERENCES categories (id),
    CONSTRAINT fk_tx_user     FOREIGN KEY (user_id)     REFERENCES users (id),
    CONSTRAINT chk_amount     CHECK (amount >= 0),
    CONSTRAINT chk_fee        CHECK (fee >= 0),
    CONSTRAINT chk_status     CHECK (status IN ('success', 'failed', 'reversed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLE: tags
-- Free-form analyst labels applied to transactions after ingestion.
-- =============================================================
CREATE TABLE IF NOT EXISTS tags (
    id   INT         NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key',
    name VARCHAR(50) NOT NULL               COMMENT 'Tag label e.g. high-value, flagged',
    PRIMARY KEY (id),
    UNIQUE KEY uq_tags_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLE: transaction_tags  (junction — resolves M:N)
-- Links transactions to tags.
-- =============================================================
CREATE TABLE IF NOT EXISTS transaction_tags (
    transaction_id INT NOT NULL COMMENT 'FK to transactions.id',
    tag_id         INT NOT NULL COMMENT 'FK to tags.id',
    PRIMARY KEY (transaction_id, tag_id),
    CONSTRAINT fk_tt_transaction FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
    CONSTRAINT fk_tt_tag         FOREIGN KEY (tag_id)         REFERENCES tags (id)         ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- TABLE: system_logs
-- ETL pipeline audit trail and per-transaction processing events.
-- transaction_id is nullable to support pipeline-level events.
-- =============================================================
CREATE TABLE IF NOT EXISTS system_logs (
    id             INT          NOT NULL AUTO_INCREMENT                COMMENT 'Surrogate primary key',
    transaction_id VARCHAR(100)                                        COMMENT 'Related MoMo reference — NULL for pipeline events',
    level          VARCHAR(10)  NOT NULL                               COMMENT 'Log severity: INFO | WARNING | ERROR',
    message        TEXT         NOT NULL                               COMMENT 'Log message body',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP     COMMENT 'Auto-set timestamp',
    PRIMARY KEY (id),
    CONSTRAINT chk_log_level CHECK (level IN ('INFO', 'WARNING', 'ERROR'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================
-- INDEXES
-- =============================================================
CREATE INDEX idx_tx_date        ON transactions (transaction_date);
CREATE INDEX idx_tx_category    ON transactions (category_id);
CREATE INDEX idx_tx_user        ON transactions (user_id);
CREATE INDEX idx_logs_level     ON system_logs  (level);
CREATE INDEX idx_logs_created   ON system_logs  (created_at);

-- =============================================================
-- SEED DATA: categories (all 11 MoMo transaction types)
-- =============================================================
INSERT INTO categories (name, description) VALUES
    ('incoming_money',          'Money received from another MoMo user'),
    ('payment_to_code_holder',  'Payment made to a merchant or agent using a code'),
    ('transfer_to_mobile',      'Transfer sent to another mobile number'),
    ('bank_deposit',            'Deposit from a linked bank account to MoMo wallet'),
    ('airtime_bill_payment',    'Airtime top-up or bill payment via MoMo'),
    ('cash_power_bill',         'Cash Power (electricity) bill payment'),
    ('third_party_transaction', 'Transaction initiated by a third-party application'),
    ('withdrawal_from_agent',   'Cash withdrawal at a MoMo agent'),
    ('bank_transfer',           'Transfer from MoMo wallet to a bank account'),
    ('internet_voice_bundle',   'Purchase of internet or voice bundle'),
    ('other',                   'Uncategorised or unrecognised SMS pattern');

-- =============================================================
-- SEED DATA: users (5 sample counterparty users)
-- =============================================================
INSERT INTO users (phone_number, name, first_seen, last_seen) VALUES
    ('+250781000001', 'Alice Uwimana',   '2024-01-05', '2024-08-20'),
    ('+250782000002', 'Bob Nkurunziza',  '2024-02-10', '2024-08-18'),
    ('+250783000003', 'Claire Mukamana', '2024-03-01', '2024-07-30'),
    ('+250784000004', 'David Habimana',  '2024-04-15', '2024-08-01'),
    ('+250785000005', 'Eve Ingabire',    '2024-05-20', '2024-08-22');

-- =============================================================
-- SEED DATA: transactions (5 sample records)
-- =============================================================
INSERT INTO transactions (transaction_id, category_id, user_id, amount, fee, balance_after, transaction_date, raw_body, status) VALUES
    ('TXN-2024-0001', 1, 1, 50000.00,    0.00, 120000.00, '2024-08-01 09:15:00',
     'You have received 50,000 RWF from Alice Uwimana (+250781000001). Your new balance is 120,000 RWF.',
     'success'),
    ('TXN-2024-0002', 3, 2, 20000.00,  200.00,  99800.00, '2024-08-05 14:30:00',
     'TXN-2024-0002: Transfer of 20,000 RWF to Bob Nkurunziza (+250782000002) successful. Fee: 200 RWF. Balance: 99,800 RWF.',
     'success'),
    ('TXN-2024-0003', 5, 3,  1000.00,    0.00,  98800.00, '2024-08-10 08:00:00',
     'Airtime payment of 1,000 RWF to Claire Mukamana (+250783000003). Balance: 98,800 RWF.',
     'success'),
    ('TXN-2024-0004', 8, 4, 30000.00,  300.00,  68500.00, '2024-08-15 11:45:00',
     'Cash withdrawal of 30,000 RWF at agent David Habimana (+250784000004). Fee: 300 RWF. Balance: 68,500 RWF.',
     'success'),
    ('TXN-2024-0005', 2, 5,  5000.00,   50.00,  63450.00, '2024-08-20 16:00:00',
     'Payment of 5,000 RWF to code holder Eve Ingabire (+250785000005). Fee: 50 RWF. Balance: 63,450 RWF.',
     'success'),
    ('TXN-2024-0006', 9, 2, 75000.00,  750.00, -12300.00, '2024-08-22 10:00:00',
     'Bank transfer of 75,000 RWF to Bob Nkurunziza (+250782000002). Fee: 750 RWF. Balance: -12,300 RWF.',
     'failed'),
    ('TXN-2024-0007', 4, 3, 100000.00,   0.00, 198800.00, '2024-08-23 13:20:00',
     'Bank deposit of 100,000 RWF from Claire Mukamana (+250783000003). Balance: 198,800 RWF.',
     'success'),
    ('TXN-2024-0008', 7, 1,  15000.00, 150.00, 183650.00, '2024-08-24 09:05:00',
     'Third-party transaction of 15,000 RWF via Alice Uwimana (+250781000001). Fee: 150 RWF. Balance: 183,650 RWF.',
     'reversed');

-- =============================================================
-- SEED DATA: tags
-- =============================================================
INSERT INTO tags (name) VALUES
    ('high-value'),
    ('flagged'),
    ('reviewed'),
    ('duplicate-check'),
    ('reconciled');

-- =============================================================
-- SEED DATA: transaction_tags
-- =============================================================
INSERT INTO transaction_tags (transaction_id, tag_id) VALUES
    (1, 1),  -- TXN-2024-0001 → high-value
    (1, 3),  -- TXN-2024-0001 → reviewed
    (2, 2),  -- TXN-2024-0002 → flagged
    (4, 1),  -- TXN-2024-0004 → high-value
    (5, 5),  -- TXN-2024-0005 → reconciled
    (7, 1),  -- TXN-2024-0007 → high-value
    (8, 2);  -- TXN-2024-0008 → flagged

-- =============================================================
-- SEED DATA: system_logs (mix of transaction-level + pipeline events)
-- =============================================================
INSERT INTO system_logs (transaction_id, level, message) VALUES
    ('TXN-2024-0001', 'INFO',    'Transaction TXN-2024-0001 parsed and inserted successfully.'),
    ('TXN-2024-0002', 'INFO',    'Transaction TXN-2024-0002 parsed and inserted successfully.'),
    ('TXN-2024-0003', 'WARNING', 'Transaction TXN-2024-0003: category matched by fallback pattern.'),
    ('TXN-2024-0004', 'INFO',    'Transaction TXN-2024-0004 parsed and inserted successfully.'),
    ('TXN-2024-0005', 'INFO',    'Transaction TXN-2024-0005 parsed and inserted successfully.'),
    (NULL,            'INFO',    'ETL pipeline started. Source file: modified_sms_v2.xml'),
    ('TXN-2024-0006', 'ERROR',   'Transaction TXN-2024-0006: bank transfer failed, insufficient balance.'),
    ('TXN-2024-0007', 'INFO',    'Transaction TXN-2024-0007 parsed and inserted successfully.'),
    ('TXN-2024-0008', 'WARNING', 'Transaction TXN-2024-0008 reversed by third-party provider.'),
    (NULL,            'INFO',    'ETL pipeline completed. 8 transactions processed, 1 error.');

-- =============================================================
-- SAMPLE CRUD OPERATIONS
-- =============================================================

-- READ: Total amount and fees per category
SELECT c.name,
       COUNT(*)        AS tx_count,
       SUM(t.amount)   AS total_amount,
       SUM(t.fee)      AS total_fees
FROM transactions t
JOIN categories c ON t.category_id = c.id
GROUP BY c.name
ORDER BY total_amount DESC;

-- READ: Top 5 users by transaction volume
SELECT u.phone_number,
       u.name,
       COUNT(*)      AS tx_count,
       SUM(t.amount) AS total_amount
FROM transactions t
JOIN users u ON t.user_id = u.id
GROUP BY u.id
ORDER BY total_amount DESC
LIMIT 5;

-- READ: All transactions carrying the 'high-value' tag
SELECT t.transaction_id, t.amount, t.transaction_date, c.name AS category
FROM transactions t
JOIN transaction_tags tt ON tt.transaction_id = t.id
JOIN tags tg             ON tg.id = tt.tag_id
JOIN categories c        ON c.id  = t.category_id
WHERE tg.name = 'high-value';

-- READ: Error log entries from the last 7 days
SELECT id, transaction_id, message, created_at
FROM system_logs
WHERE level = 'ERROR'
  AND created_at >= NOW() - INTERVAL 7 DAY
ORDER BY created_at DESC;

-- READ: Monthly transaction totals
SELECT DATE_FORMAT(transaction_date, '%Y-%m') AS month,
       COUNT(*)      AS tx_count,
       SUM(amount)   AS total_amount,
       SUM(fee)      AS total_fees
FROM transactions
GROUP BY month
ORDER BY month;

-- UPDATE: Mark a transaction as reversed
UPDATE transactions
SET status = 'reversed'
WHERE transaction_id = 'TXN-2024-0003';

-- DELETE: Remove a tag assignment (not the tag itself)
DELETE FROM transaction_tags
WHERE transaction_id = (SELECT id FROM transactions WHERE transaction_id = 'TXN-2024-0003')
  AND tag_id         = (SELECT id FROM tags WHERE name = 'duplicate-check');
