# CodeSync — MoMo SMS Analytics Platform

**Team:** CodeSync
**Week 2:** Database Design and Implementation

---

## Project Overview

This system processes MoMo mobile money SMS data exported from XML, stores it in
a structured MySQL database, and exposes it through a dashboard and API. The
pipeline extracts transactions, categorises them by SMS pattern, links them to
counterparty users, and logs every processing event for auditability.

---

## Repository Structure

```
/
├── README.md
├── COLLABORATION.md               ← team task guide and git workflow
├── docs/
│   ├── erd_diagram.png            ← Entity Relationship Diagram
│   ├── design_document.md         ← rationale, data dictionary, queries, security rules
│   └── ai_usage_log.md            ← full AI interaction log
├── database/
│   └── database_setup.sql         ← DDL + indexes + seed data + sample DML + CRUD queries
├── examples/
│   └── json_schemas.json          ← JSON representations of all entities + SQL-to-JSON mapping
└── data/
    └── processed/
        └── dashboard.json         ← dashboard KPI and category structure
```

---

## Database Design

The MySQL database (`momo`) is initialised by running:

```bash
mysql -u root -p momo < database/database_setup.sql
```

### Tables

| Table | Purpose |
|---|---|
| `categories` | Lookup table for 11 MoMo transaction types |
| `users` | Unique counterparty phone numbers and names |
| `transactions` | Core table — one row per MoMo SMS transaction |
| `tags` | Free-form analyst labels (high-value, flagged, etc.) |
| `transaction_tags` | Junction table resolving M:N between transactions and tags |
| `system_logs` | ETL pipeline audit trail and per-transaction processing events |

### Key Design Decisions

- **Foreign keys** enforced via `InnoDB` engine on all tables
- **CHECK constraints** on `amount >= 0`, `fee >= 0`, `status`, and `level` values
- **UNIQUE constraints** on `transaction_id`, `phone_number`, `categories.name`, `tags.name`
- **Indexes** on `transaction_date`, `category_id`, `user_id`, `level`, `created_at`
- **raw_body** column preserves original SMS text for traceability and re-processing
- **M:N relationship** between transactions and tags resolved with `transaction_tags` junction table

### ERD

See [`docs/erd_diagram.png`](docs/erd_diagram.png) for the full Entity Relationship Diagram.

Full design rationale, data dictionary, sample queries, and security rules are in
[`docs/design_document.md`](docs/design_document.md).

---

## JSON Schemas

[`examples/json_schemas.json`](examples/json_schemas.json) contains:

- Individual JSON representations of all 5 entities
- A complex nested transaction object with category, user, tags array, and logs array
- An explicit SQL column → JSON field mapping table

---

## Team

| Member | Branch | Role |
|---|---|---|
| Chol Mach Kuol Chol | `feature/project-lead` | ERD, Design Document, README, Scrum board |
| Kuol Akech Riak Kuol | `feature/database-api` | SQL schema, JSON schemas |
| Alier Akuang Alier Piel | `feature/etl` | ETL scripts, tests, AI usage log |
| Abay Mulat Tessema | `feature/frontend-dashboard` | Dashboard JSON |

---

## Scrum Board

Sprint progress and task tracking: [CodeSync Scrum Board](https://github.com/users/Chol-Mach-Kuol/projects/2)

---

## AI Usage

AI was used only for grammar checks and keyword spelling confirmation.
All schema design, business logic, and technical decisions were made by the team.
See [`docs/ai_usage_log.md`](docs/ai_usage_log.md) for the full interaction log.
