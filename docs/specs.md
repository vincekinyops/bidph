# Bidph — Project Specs

## Overview
Bidph is a Phoenix + LiveView auction platform with GraphQL APIs, real‑time bidding, wallets, payment methods, and Stripe‑based top‑ups. The UI follows a modern auction marketplace design and includes a featured auction hero, hot auctions grid, stats strip, and a registration CTA.

## Tech Stack
- **Elixir**: Phoenix framework
- **Phoenix LiveView**: real‑time UI (listings, bidding, wallet, profile)
- **Absinthe GraphQL**: API at `/api` with GraphiQL at `/graphiql`
- **Postgres**: primary database via Ecto
- **Swoosh**: email delivery (SMTP configured via env)
- **Stripe**: payment methods and wallet top‑ups (Stripe.js + webhooks)
- **Tailwind + daisyUI**: styling
- **Heroicons**: icons

## Core Features Implemented
- **User auth**: registration/login/settings (Phoenix auth generator)
- **Listings**: create listings, browse, and view single listing
- **Bidding**: place bids with validation + winning bid tracking
- **Wallet**: balance + held balance, top‑ups, transactions
- **Payment methods**: add methods, verify (manual + webhooks)
- **Stripe**: attach card and create top‑up intents via Stripe.js
- **Profile & My Listings**: manage user listings and toggle bidding status
- **Admin**: super‑admin dashboard and seeding support
- **Landing UI**: featured auction, hot auctions, stats, CTA (with mock images)

## App Routes (Browser)
- `/` — Landing page
- `/listings` — Browse listings (LiveView)
- `/listings/new` — Upload product (LiveView)
- `/listings/:id` — Single product bidding page (LiveView)
- `/wallet` — Wallet top‑up + transactions (LiveView)
- `/payment-methods` — Payment methods (LiveView)
- `/profile` — Profile summary (LiveView)
- `/my-listings` — Listings management (LiveView)
- `/admin` — Admin dashboard (LiveView, super‑admin only)

## API Routes
### GraphQL
- `POST /api` — Absinthe GraphQL API
- `GET /graphiql` — Playground

### Webhooks
- `POST /webhooks/payments` — Generic payments webhook (secret header)
- `POST /webhooks/stripe` — Stripe webhook (signature verified)

## Wallet & Bidding Rules
1. **User must have a verified payment method**.
2. **User must have wallet balance ≥ bid amount**.
3. On bid:
   - Previous winning bid is released (hold removed)
   - New bid is recorded and listing price updated
   - Funds are held (wallet balance → held balance)

## Data Models (Main)
### Users
`users`
- `email`, `hashed_password`, profile fields
- `is_super_admin`
- `stripe_customer_id`

### Listings
`listings`
- `title`, `description`, `starting_price`, `current_price`
- `category`, `image_urls`, `status` (`active|paused|ended|sold|cancelled`)
- `end_at`, `user_id`

### Bids
`bids`
- `amount`, `is_winning`, `listing_id`, `user_id`

### Wallets
`wallets`
- `user_id`, `balance`, `held_balance`

### Wallet Transactions
`wallet_transactions`
- `wallet_id`, `amount`, `transaction_type`
- `provider`, `reference`
- `receipt_number`, `receipt_url`, `external_id`

### Payment Methods
`payment_methods`
- `user_id`, `provider`, `method_type`
- `last4`, `status` (`pending|active|inactive|failed`)
- `external_id`, `verified_at`

### Payment Holds
`payment_holds`
- `user_id`, `payment_method_id`, `bid_id`, `amount`, `status`

## Stripe Integration
### Client
- Stripe.js loaded in `root.html.heex`
- Publishable key via `<meta name="stripe-publishable-key">`

### Payment Methods
- Card element rendered in `/payment-methods`
- Creates Stripe PaymentMethod and attaches to customer
- Stored as `payment_methods` with `external_id=pm_...`

### Wallet Top‑ups
- `/wallet` creates Stripe PaymentIntent
- Client confirms PaymentIntent with Stripe.js
- Webhook `payment_intent.succeeded` credits wallet + creates receipt

### Webhooks
- Verified using **Stripe‑Signature** with HMAC (5‑minute tolerance)

## Emailing
- Swoosh SMTP configured in `config/runtime.exs`
- Notifications:
  - `Wallet Top‑up Receipt`
  - `Payment Method Verified`

## Environment Variables
Copy `.env.example` to `.env` and fill:

### Auth/Admin
- `FIRST_SUPER_ADMIN_EMAIL`
- `FIRST_SUPER_ADMIN_PASSWORD`

### Mail
- `MAIL_FROM`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_TLS`

### Payments (generic)
- `PAYMENTS_WEBHOOK_SECRET`
- `GCASH_API_KEY`
- `MAYA_API_KEY`
- `BANK_API_KEY`

### Stripe
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`

## How to Run
```bash
mix ecto.migrate
mix phx.server
```

Optional seed data:
```bash
mix run priv/repo/seeds.exs
```

## Notes / Known Limitations
- Stripe webhook uses raw body verification; server must receive unmodified payload.
- Stripe flows are minimal; production should use SetupIntents + proper status handling.
- Mock images served from `/assets/mock/...`
