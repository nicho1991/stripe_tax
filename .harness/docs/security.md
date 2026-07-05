# Security

This app processes Stripe financial data (payouts, transactions, customer info) and writes untrusted CSV input to the database. Security is non-negotiable.

## CI gate

`bin/brakeman --no-pager` runs on every PR (CI job: `scan_ruby`). New high-confidence warnings block merge.

## Threat surface

| Surface | Risk | Mitigation |
|---|---|---|
| CSV upload (payout + transactions) | Malformed / malicious CSV, formula injection, SQL injection via strings | Parse via dedicated service (`PayoutCsvParser`, `TransactionCsvParser`); never pass raw CSV to Active Record; sanitize formula prefixes |
| Country code override UI | User sets invalid code → wrong tax classification | Validate against ISO 3166-1 alpha-2 (gem: `countries`); UI must surface override visibly in PDF |
| EU classification | Wrong classification = wrong tax report | All classification routes through `EuClassificationService`; manual override always wins; assert in tests |
| PDF generation (`prawn`) | Prawn can execute arbitrary content; XSS via filenames | Sanitize strings passed into Prawn; never embed raw user HTML |
| Authentication | Brakeman-flagged mass-assignment / weak password rules | Use Rails 8 `has_secure_password`; brakeman covers common auth issues |
| Secrets | Stripe keys leaked into repo | `.env` in `.gitignore`; rotate immediately if leaked; check `git log -p` for accidental commits |

## Pre-commit checklist

- [ ] No raw `params[:foo]` passed to Active Record without strong params
- [ ] No new `system`, `exec`, backticks, `open("|...")` calls
- [ ] No new SQL string interpolation (use `?` placeholders or Arel)
- [ ] New endpoints gated by `authenticate_user!` (or an explicit, justified exception)
- [ ] CSRF protection intact for any new form
- [ ] PDF / CSV output strings are sanitized

## What `code-reviewer` checks

- `bin/brakeman --no-pager` is clean
- No new attack surface in `app/controllers/` or `app/services/`
- Country code validation matches the `countries` gem's whitelist
- Manual country code overrides are visibly rendered in the PDF (no silent overrides)

## If you suspect a leak

1. Rotate the key in Stripe dashboard immediately
2. `git log -p -- <suspected-file>` to confirm exposure scope
3. `git filter-repo` or BFG to scrub history (only with user approval)
4. File an incident note in `.harness/incidents/<date>.md`