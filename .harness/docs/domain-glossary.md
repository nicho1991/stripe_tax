# Domain Glossary — Stripe Tax / Danish Accounting

## Core entities

| Term | Meaning | Code |
|---|---|---|
| **Payout** | A Stripe payout period; CSV lists transaction IDs only | `app/models/payout.rb` |
| **Transaction** | Detailed Stripe transaction (income, fee, customer country, currency) | `app/models/transaction.rb` |
| **Payment** | Local join between Payout and Transaction; carries `eu_classification` and optional `manual_country_code` | `app/models/payment.rb` |

## EU classification

Four buckets (`payment.eu_classification`):

| Bucket | Meaning |
|---|---|
| `eu` | Customer country is in the EU |
| `non_eu` | Customer country is outside the EU |
| `stripe_fees` | Stripe's own fee transactions (no customer country) |
| `undetermined` | Country could not be inferred (UI surfaces a manual-override affordance) |

All classification goes through `app/services/eu_classification_service.rb`. Do not roll ad-hoc classification logic.

## Manual country code override

`payment.manual_country_code` (nullable). When set, it **always overrides** the inferred classification. The PDF must surface the override visibly — silently overriding is a bug.

## Danish accounting output

| Term | Meaning |
|---|---|
| **Kontoplan** | Chart of accounts (Danish bookkeeping standard) |
| **Bogføring** | Bookkeeping entries; rendered into the payout PDF |
| **Afstemning** | Reconciliation; the `Payouts/Show` view renders `afstem med 5840 stripe konto` to match against account 5840 (Stripe bank account) |

## PDF rendering

`PayoutPdfService` uses `prawn` + `prawn-table`. Sections (current):

- **Kontoplan bogføring** — chart of accounts / bookkeeping entries, grouped by classification
- **Afstem med 5840 stripe konto** — reconciliation footer note

## Workflow

1. User uploads **Payout CSV** → creates a `Payout` record with raw transaction IDs
2. User uploads **Transactions CSV** → matches IDs to detailed `Transaction` records
3. `TransactionImportService` creates `Payment` join records and assigns `eu_classification` via `EuClassificationService`
4. `Payouts/Show` displays totals (EU / non-EU / stripe_fees) and renders the PDF on demand
5. Accountant hand-off: PDF is the deliverable (kontoplan bogføring + afstemning)

## Recent domain work (last 6 weeks)

- `feat/payout-booking-info-and-reconcile-note` — add `afstem med 5840 stripe konto` note + kontoplan bogføring PDF section
- `feature/manual-country-code-override` — allow UI override of inferred country code; PDF must respect override
- `stripe_fees` as 4th EU classification category with PDF reports