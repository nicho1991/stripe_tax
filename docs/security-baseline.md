# Security Baseline — feature/stripe-import-phase-1

Captured after the three security pre-flight commits on
`feature/stripe-import-phase-1` (see git log: `cd82679`, `efa3fd7`,
`e5d9195`).

## Summary

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| bundler-audit CVEs | 144 | 7 | **−137 cleared** |
| brakeman warnings (`--no-threads`) | untrusted signal (7.x silent threading on Rails 8) | 0 (8.0.5) | signal now reliable |

The owner-scoped directive was rack + rack-session + rails-8.0.4.x +
brakeman-8.x (Option 1 + 2). The umbrella rails bump pulled in
nokogiri 1.19.4 transitively, which collapsed the bulk of the
remaining CVEs; the final 7 sit in five gems outside the rails family
and are intentionally deferred per the option scope.

## Cleared in this branch

### Commit `cd82679` — rack + rack-session

Pinned `rack ~> 3.2.6` and `rack-session ~> 2.1.2`. Clears the three
CVEs the owner flagged:

- **GHSA-q2ww-5357-x388** — Rack Content-Length mismatch in
  `Rack::Files` error responses.
- **GHSA-g2pf-xv49-m2h5** — `Rack::Request` accepts invalid Host
  characters, enabling host allowlist bypass.
- **GHSA-33qg-7wpp-89cq** — `Rack::Session::Cookie` secrets: decrypt
  failure fallback enables secretless session forgery and Marshal
  deserialization.

The pins were added to the Gemfile because rack / rack-session are
transitive deps of rails — without an explicit entry, `bundle lock
--update=rack,rack-session` errors with "Could not find gem".

### Commit `efa3fd7` — rails >= 8.0.4.1

Changed `gem "rails", "~> 8.0.4"` to `gem "rails", "~> 8.0.4",
">= 8.0.4.1"`. Bundler resolved to rails 8.0.5 (latest 8.0.x ≥
8.0.4.1), pulling the entire rails family to 8.0.5 and bumping many
transitive deps (notably nokogiri 1.18.10 → 1.19.4, which collapsed
~96 nokogiri CVEs by itself). Cleared CVEs span actionview,
activestorage, activesupport, nokogiri, and the wider 8.0.4 →
8.0.5 transitive-dep cascade.

The lockfile diff is "rails family + transitive deps only" — no
unrelated gems added or removed.

### Commit `e5d9195` — brakeman 8.x

Changed `gem "brakeman"` to `gem "brakeman", "~> 8.0"`. Bundler
resolved to 8.0.5. This is a verification-signal fix, not a CVE fix:
7.x has a silent threading failure on Rails 8 (per agent memory),
so the 0-warning signal brakeman reported on the old Gemfile.lock was
not trustworthy. After this bump `bin/brakeman --no-threads --no-pager
-q` exits 0 with no findings — that's the signal this PR is built on
top of.

## Deferred to follow-up security PR

7 CVEs remain across 5 gems. All are outside the rails family and
outside the owner's chosen scope (rack / rack-session / rails).

| Gem | CVEs | Severity | Fix | Notes |
| --- | ---: | --- | --- | --- |
| `addressable` 2.8.7 | 1 | High | `>= 2.9.0` | ReDoS in Addressable templates (GHSA-h27x-rffw-24p4). |
| `bcrypt` 3.1.20 | 1 | Unknown | `>= 3.1.22` | JRuby-only integer overflow at cost=31 (GHSA-f27w-vcwj-c954). Dependabot already has `dependabot/bundler/bcrypt-3.1.21` open; will merge on its own. |
| `json` 2.16.0 | 2 | Unknown + Low | `>= 2.19.9` (or `~> 2.15.2.1` / `~> 2.17.1.2`) | Format-string injection (GHSA-3m6g-2423-7cp3) and heap buffer overflow in streaming IO (GHSA-x2f5-4prf-w687). |
| `msgpack` 1.8.0 | 1 | Unknown | `>= 1.8.2` | Use-after-free in `MessagePack::Buffer#clear` (GHSA-4mrv-5p47-p938). |
| `puma` 7.1.0 | 2 | High + High | `~> 7.2.1` or `>= 8.0.2` | PROXY Protocol v1 memory exhaustion (GHSA-qpgp-93vx-g8v8) and repeated-header DoS on persistent connections (GHSA-2vqw-3mp8-cgmx). |

**Total outstanding: 7 CVEs** (1 High, 2 High puma, 2 Unknown json +
msgpack + bcrypt, 1 Low).

## Implied follow-up scope

The follow-up security PR should bump:

```ruby
gem "addressable", ">= 2.9.0"   # or rely on capybara transitive bump
gem "bcrypt", "~> 3.1.22"        # already queued by dependabot
gem "json", ">= 2.19.9"          # major ruby/json bump; check Ruby compat
gem "msgpack", ">= 1.8.2"        # small patch bump
gem "puma", ">= 7.2.1"           # minor bump; 7.2.x is current stable
```

`puma` is the only High-severity outstanding item — recommend bumping
that one first as a standalone PR, then the four others as a batch.

## Why not a full sweep

A `bundle update` (everything) would have cleared all 7 plus any
zero-days not yet in the bundler-audit database. It was explicitly
out of scope (Option 3, owner said "unlikely"). It also violates the
"conservative gem bump" rule in agent memory and is high-risk for
regressions on a single PR.