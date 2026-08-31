# Kiddotasks

Kiddotasks is a native iOS family chore app. Parents manage household routines,
approvals, rewards, and activity from their phones. Children use a shared iPad
to complete missions, track earned points, request rewards, and celebrate
progress—without needing an email address or account.

The product specification, agreed decisions, and phased implementation roadmap
live in [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md).

## Current status

The app currently provides a local-first SwiftUI prototype. Firebase models,
security rules, and Cloud Functions are scaffolded for a future synchronized
multi-device release. Work is now progressing from the agreed product
specification, beginning with parent-approval rules for chores.

## Project layout

- `Kiddotasks/` — SwiftUI app, screens, models, design system, and services.
- `KiddotasksTests/` — unit tests.
- `Firebase/` — Firestore rules and Cloud Functions source.
- `docs/` — product and engineering documentation.
