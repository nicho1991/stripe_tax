# Code Style

## Ruby

- Authoritative style: `rubocop-rails-omakase` (configured in `.rubocop.yml`)
- Do not hand-author style preferences — run `bin/rubocop -A` for safe autocorrects, then resolve the rest manually
- Ruby version: 3.3.0 (see `.ruby-version`)
- Patterns:
  - Controllers stay thin: parse params, call a service, render an Inertia response
  - CSV / PDF / classification logic lives in `app/services/` — never in controllers or models
  - Use Active Record query interface; avoid raw SQL unless performance-critical
  - Prefer service objects over concerns when adding business logic to a model

## TypeScript / React

- Strict TypeScript; `npm run check` (= `tsc -p tsconfig.app.json && tsc -p tsconfig.node.json`) must pass
- React 19 functional components only; no class components
- Tailwind 4 + DaisyUI 5: prefer DaisyUI components over custom CSS
- File layout: `app/frontend/pages/<Resource>/<Action>.tsx` mirrors Rails routes
- Imports: use the `@/` alias if configured; otherwise relative imports within `app/frontend/`
- Inertia page props are typed; use `usePage<{ payout: Payout }>()` patterns

## Naming

- Ruby: `snake_case` files and methods, `PascalCase` classes
- React components: `PascalCase` exports, file name matches (`Payouts/Show.tsx` exports `Show`)
- TypeScript modules (non-component): `kebab-case.ts`
- Database columns: `snake_case`; `eu_classification`, `manual_country_code` are existing examples

## Commit messages

Conventional Commits, observed in `git log`:

- `feat:` new behavior
- `fix:` bug fix
- `chore:` maintenance / deps / rubocop autocorrect
- `chore(deps):` dependency bumps

## Branch naming

- `feat/<slug>` for new behavior
- `fix/<slug>` for bug fixes
- `feature/<slug>` was used historically; either is accepted but `feat/` is preferred going forward

## What not to do

- Don't bypass `EuClassificationService` with ad-hoc classification logic in controllers
- Don't inline CSV parsing — use the parsers in `app/services/`
- Don't introduce a class component or a non-Inertia page (no separate React Router)
- Don't hand-author Ruby style — let Omakase decide