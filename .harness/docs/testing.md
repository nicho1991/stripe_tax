# Testing

## Framework

Minitest (Rails default). System tests use Capybara + headless Chrome via `selenium-webdriver`.

## File layout

Mirror `app/` under `test/`:

- `app/services/foo.rb` → `test/services/foo_test.rb`
- `app/models/foo.rb` → `test/models/foo_test.rb`
- `app/controllers/foo_controller.rb` → `test/controllers/foo_controller_test.rb`
- System / integration tests live under `test/system/` and `test/integration/`
- Fixtures: `test/fixtures/` (`.yml`)

The reference test in this codebase is `test/services/eu_classification_service_test.rb`.

## Running tests locally

Fast loop (unit + controller):

```bash
bin/rails test
```

Full CI parity (unit + system, requires Postgres):

```bash
RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5432 \
  bin/rails db:test:prepare test test:system
```

The CI `test` job uses the command above.

## What to cover

- Every new public method in `app/services/` gets a unit test asserting each branch
- Every new controller action gets at least one controller test
- Every new migration / model field gets a model test (validation + scope)
- Every new EU classification branch — `eu`, `non_eu`, `stripe_fees`, `undetermined` — must have explicit test coverage; `stripe_fees` was added late and is easy to miss
- Every manual country code override scenario must round-trip through the PDF (`PayoutPdfService`) and be visible in the rendered output

## System test rules

- No `sleep` — use Capybara matchers and `wait_for_*` helpers
- Test against the full app stack (Capybara `app_host`)
- Keep fixtures deterministic; if a test needs non-deterministic data, seed it in the test body, not a fixture

## Coverage

SimpleCov is not currently configured. New behavior without matching tests will be flagged in PR review by the `code-reviewer` rein.

## CI parity

Three CI gates, all must be green on a PR:

1. `scan_ruby` — `bin/brakeman --no-pager`
2. `lint` — `bin/rubocop -f github`
3. `test` — `bin/rails db:test:prepare test test:system`