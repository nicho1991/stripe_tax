# AGENTS.md

Web app that reconciles Stripe payouts against detailed transaction CSVs, classifies each payment as EU / non-EU / stripe_fees / unknown, and produces Danish kontoplan / bogføring PDFs for accounting. Rails 8 + Inertia.js + React 19 + Vite + PostgreSQL.

## Setup commands

- Install Ruby deps:   `bundle install`
- Install JS deps:     `npm install`
- DB setup:            `bin/rails db:create db:migrate`
- Start dev (Rails + Vite): `bin/dev`
- Build / typecheck JS:      `npm run check`   (`tsc -p tsconfig.app.json && tsc -p tsconfig.node.json`)
- Test:         `bin/rails test test:system`   # uses PostgreSQL via `DATABASE_URL` (test job uses `postgres://postgres:postgres@localhost:5432`)
- Lint Ruby:    `bin/rubocop -f github`
- Security scan: `bin/brakeman --no-pager`
- Required Ruby: 3.3.0 (see `.ruby-version`)

## Project layout

- `app/controllers/` — Inertia actions: `home`, `dashboard`, `payouts`, `transactions`, `customers`, plus auth (`sessions`, `registrations`, `passwords`)
- `app/models/` — `payout.rb`, `payment.rb`, `transaction.rb`, `user.rb`, `session.rb`
- `app/services/` — CSV parsing & import (`payout_csv_parser`, `transaction_csv_parser`, `transaction_import_service`), EU classification (`eu_classification_service`), PDF rendering (`payout_pdf_service`)
- `app/frontend/pages/` — React/Inertia pages, grouped by resource (`Payouts/`, `Transactions/`, `Customers/`, `Dashboard/`)
- `app/frontend/entrypoints/` — `application.{js,css}`, `inertia.ts`
- `db/migrate/` — payouts, payments (+ `eu_classification`, `manual_country_code`), transactions, sessions, users
- `test/` — Minitest: `models/`, `controllers/`, `services/`, `system/`, `integration/`, `fixtures/`
- `config/` — Rails 8 stack including `solid_queue` / `solid_cache` (default Rails 8)

## Code style

- Ruby: `rubocop-rails-omakase` (see `.rubocop.yml` — `inherit_gem: rubocop-rails-omakase`); do not hand-author style, let Omakase decide and `rubocop -A` autocorrect when safe
- TypeScript: strict, checked by `npm run check`; React 19 functional components, no class components
- Tailwind 4 + DaisyUI 5 — utility-first; prefer DaisyUI components over custom CSS
- Inertia: controllers return `render inertia: "Resource/Page", props: {...}`; pages live under `app/frontend/pages/<Resource>/<Action>.tsx`
- CSV / PDF logic lives in `app/services/`, never in controllers
- Naming: snake_case Ruby, PascalCase React components, kebab-case filenames for non-component TS modules

## Testing instructions

- Framework: Minitest (Rails default). Test files mirror `app/` under `test/` — `test/services/eu_classification_service_test.rb` is the reference
- Run the full suite the way CI does: `bin/rails db:test:prepare test test:system` (the CI `test` job uses `RAILS_ENV=test` with `DATABASE_URL=postgres://postgres:postgres@localhost:5432`)
- System tests use Capybara + headless Chrome (`selenium-webdriver`); keep them deterministic — no `sleep`, use Capybara matchers
- Add a test for every new behavior in the same package (`test/services/`, `test/models/`, `test/controllers/`)
- All tests must pass before opening a PR

## PR & commit conventions

- Branch from `main`; never push to it directly. Feature branches seen in history: `feat/payout-booking-info-and-reconcile-note`, `feature/manual-country-code-override`
- Commit message style: Conventional Commits — `feat:`, `fix:`, `chore:`, `chore(deps):`; observed in `git log`
- CI must be green on the PR (jobs: `scan_ruby` = brakeman, `lint` = rubocop, `test` = Minitest + system tests)
- PR via `gh pr create` once CI is green; link the issue / describe the Stripe data flow if relevant

## Security

- Never commit secrets — `.env` is in `.gitignore`. Real Stripe keys / CSV exports never belong in the repo
- This app handles Stripe financial data: every PR runs `bin/brakeman --no-pager` in CI; new endpoints / models must not introduce warnings
- CSV uploads parse untrusted input — sanitize / validate before persisting (see `app/services/transaction_csv_parser.rb` for current pattern)
- Country code overrides (`manual_country_code` on `payments`) affect PDF output — UI affordance must make the override visible to the user

## Domain glossary

- **Payout** — A Stripe payout period; CSV lists transaction IDs only
- **Transaction** — Detailed Stripe transaction record (income, fee, customer country)
- **Payment** — Local join model between payout and transaction; carries `eu_classification` and optional `manual_country_code`
- **EU classification** — One of `eu`, `non_eu`, `stripe_fees`, `undetermined` (see `EuClassificationService`)
- **Kontoplan / bogføring** — Danish chart of accounts / bookkeeping. Rendered into the payout PDF for accountant hand-off
- **Afstemning** — Reconciliation. `Payouts/Show` renders an `afstem med 5840 stripe konto` note for matching against account 5840