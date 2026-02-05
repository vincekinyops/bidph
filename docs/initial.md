# BidPho — Bidding Website Plan

A real-time bidding marketplace built with Elixir and Phoenix. Anyone can list items; anyone can bid until auction end. Includes payments, escrow, accounts, notifications, live data, and live chat.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | Elixir 1.16+ |
| Web Framework | Phoenix 1.7+ |
| API | GraphQL (Absinthe) |
| Real-time UI | Phoenix LiveView |
| WebSockets | Phoenix Channels |
| GraphQL Subscriptions | Absinthe.Phoenix.Subscription |
| Database | PostgreSQL |
| Payments | Stripe (or similar) |
| Background Jobs | Oban |
| Caching | ETS / Redis (optional) |

---

## Core Features

### 1. Accounts & Authentication

- **User accounts** via `phx.gen.auth` or Pow
- Email/password auth + optional OAuth (Google, GitHub)
- Profile: avatar, display name, bio, seller rating
- Email verification
- Password reset
- Rate limiting and abuse protection

### 2. Listings & Bidding

- **Create listings**: title, description, photos, starting price, reserve price (optional), end time
- **Bidding**: users place bids; system validates (higher than current, before end time)
- **Auction rules**: hard end time; optional auto-extend (e.g. last 5 minutes)
- **Bid history** visible to all
- **Winner selection** at end time
- **Categories/tags** for browsing and search

### 3. Payments & Escrow

- **Escrow flow**:
  1. Buyer pays into escrow when auction ends
  2. Seller ships item
  3. Buyer confirms receipt → funds released to seller
  4. Dispute path if not resolved
- **Payment provider**: Stripe Connect (marketplace) or similar
- **Fee structure**: platform fee (e.g. % of sale) + payment processing
- **Payouts** to sellers via Stripe Connect payouts
- **Refunds** and partial refunds via provider APIs

### 4. Live Data

- **GraphQL** for API (queries, mutations); **GraphQL subscriptions** for real-time bid/auction updates
- **Phoenix LiveView** for main UI (server-rendered) — can consume GraphQL via client JS or stay HTML-first
- **Live updates** for:
  - Current highest bid
  - Bid count
  - Time remaining
  - New bids
  - Auction end (winner, final price)
- **Phoenix PubSub** to push updates to connected clients
- **Channels** per listing for real-time bid stream

### 5. Notifications

- **In-app**: LiveView toast/alert components; unread badge
- **Email** (Bamboo/Swoosh): outbid, auction won/lost, payment received, shipping updates
- **Optional**: push (web push API)
- **Preferences**: per-user opt-in/opt-out per notification type
- **Background delivery** via Oban workers

### 6. Live Chat

- **Phoenix Channels** for chat
- **Chat rooms** per listing (buyer ↔ seller, or general Q&A)
- **Persistent messages** in DB
- **Presence** for online users
- **Unread indicators** and basic moderation
- **File attachments** (images) if desired

---

## Architecture

### Application Structure

```
lib/
├── bidph/
│   ├── application.ex
│   ├── accounts/          # User, auth, profile
│   │   ├── user.ex
│   │   └── ...
│   ├── listings/          # Listings, bids
│   │   ├── listing.ex
│   │   ├── bid.ex
│   │   └── ...
│   ├── payments/          # Escrow, transactions
│   │   ├── escrow.ex
│   │   ├── transaction.ex
│   │   └── stripe.ex
│   ├── chat/              # Messages, rooms
│   │   ├── room.ex
│   │   ├── message.ex
│   │   └── ...
│   └── notifications/
│       ├── notification.ex
│       └── ...
├── bidph_web/
│   ├── live/
│   │   ├── listing_live/     # Listing & bid UI
│   │   ├── chat_live/        # Chat UI
│   │   └── ...
│   ├── channels/
│   │   ├── listing_channel.ex   # Live bids (or via GraphQL subscriptions)
│   │   └── chat_channel.ex      # Live chat
│   ├── graphql/                  # Absinthe GraphQL
│   │   ├── schema.ex
│   │   ├── resolvers/
│   │   │   ├── listing_resolver.ex
│   │   │   ├── bid_resolver.ex
│   │   │   ├── user_resolver.ex
│   │   │   ├── chat_resolver.ex
│   │   │   └── ...
│   │   ├── mutations/
│   │   ├── subscriptions/
│   │   │   ├── listing_subscription.ex
│   │   │   └── chat_subscription.ex
│   │   └── types/
│   └── components/
```

### Real-time Flow

```
User A bids → ListingChannel / GraphQL subscription broadcasts → All clients (LiveView + JS) update
Auction ends → Oban job runs → Escrow created → Emails + notifications sent
Chat message → ChatChannel / GraphQL subscription broadcasts → All users in room receive it
```

---

## Database Schema (Detailed)

### users

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| email | varchar(255) | NOT NULL, UNIQUE |
| hashed_password | varchar(255) | NOT NULL |
| confirmed_at | timestamp | |
| display_name | varchar(100) | |
| avatar_url | varchar(500) | |
| bio | text | |
| stripe_account_id | varchar(255) | (for Connect payouts) |
| inserted_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Indexes:** `email` (unique), `stripe_account_id`

---

### listings

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| user_id | bigint | NOT NULL, FK → users |
| title | varchar(255) | NOT NULL |
| description | text | |
| starting_price | decimal(12,2) | NOT NULL |
| reserve_price | decimal(12,2) | (optional minimum to sell) |
| current_price | decimal(12,2) | NOT NULL |
| status | varchar(20) | NOT NULL (`active`, `ended`, `sold`, `cancelled`) |
| end_at | timestamp | NOT NULL |
| category | varchar(100) | |
| image_urls | jsonb | array of URLs |
| inserted_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Indexes:** `user_id`, `status`, `end_at`, `category`, `(status, end_at)` (for active auctions)

---

### bids

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| listing_id | bigint | NOT NULL, FK → listings |
| user_id | bigint | NOT NULL, FK → users |
| amount | decimal(12,2) | NOT NULL |
| is_winning | boolean | DEFAULT false |
| inserted_at | timestamp | NOT NULL |

**Indexes:** `listing_id`, `user_id`, `(listing_id, amount DESC)` (for current high bid)

**Constraints:** UNIQUE `(listing_id, user_id)` only if one bid per user per listing; otherwise allow multiple bids from same user.

---

### escrows

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| listing_id | bigint | NOT NULL, FK → listings |
| buyer_id | bigint | NOT NULL, FK → users |
| seller_id | bigint | NOT NULL, FK → users |
| amount | decimal(12,2) | NOT NULL |
| platform_fee | decimal(12,2) | NOT NULL |
| status | varchar(20) | NOT NULL (`pending`, `paid`, `shipped`, `released`, `disputed`, `refunded`) |
| stripe_payment_intent_id | varchar(255) | |
| released_at | timestamp | |
| inserted_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Indexes:** `listing_id`, `buyer_id`, `seller_id`, `status`

---

### transactions

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| escrow_id | bigint | FK → escrows |
| user_id | bigint | NOT NULL, FK → users |
| type | varchar(30) | NOT NULL (`payment`, `release`, `refund`, `payout`, `fee`) |
| amount | decimal(12,2) | NOT NULL |
| stripe_id | varchar(255) | |
| metadata | jsonb | |
| inserted_at | timestamp | NOT NULL |

**Indexes:** `escrow_id`, `user_id`, `type`

---

### chat_rooms

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| listing_id | bigint | NOT NULL, FK → listings, UNIQUE |
| inserted_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Indexes:** `listing_id` (unique)

---

### chat_room_participants

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| chat_room_id | bigint | NOT NULL, FK → chat_rooms |
| user_id | bigint | NOT NULL, FK → users |
| last_read_at | timestamp | |
| inserted_at | timestamp | NOT NULL |

**Indexes:** `(chat_room_id, user_id)` UNIQUE

---

### messages

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| chat_room_id | bigint | NOT NULL, FK → chat_rooms |
| user_id | bigint | NOT NULL, FK → users |
| body | text | NOT NULL |
| inserted_at | timestamp | NOT NULL |

**Indexes:** `chat_room_id`, `(chat_room_id, inserted_at)` (for pagination)

---

### notifications

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| user_id | bigint | NOT NULL, FK → users |
| type | varchar(50) | NOT NULL (`outbid`, `auction_won`, `auction_lost`, `payment_received`, etc.) |
| title | varchar(255) | NOT NULL |
| body | text | |
| read_at | timestamp | |
| link_path | varchar(500) | |
| metadata | jsonb | |
| inserted_at | timestamp | NOT NULL |

**Indexes:** `user_id`, `(user_id, read_at)` (for unread)

---

### notification_preferences

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigserial | PK |
| user_id | bigint | NOT NULL, FK → users |
| type | varchar(50) | NOT NULL |
| email_enabled | boolean | DEFAULT true |
| in_app_enabled | boolean | DEFAULT true |
| inserted_at | timestamp | NOT NULL |
| updated_at | timestamp | NOT NULL |

**Indexes:** `(user_id, type)` UNIQUE

---

### Key Relationships

- `User` has many `Listings`, `Bids`, `Escrows` (as buyer/seller), `Notifications`, `Messages`
- `Listing` has many `Bids`, belongs to `User`, has one `ChatRoom`, has one `Escrow`
- `ChatRoom` has many `Messages`, many `Users` through `chat_room_participants`
- `Escrow` has many `Transactions`, belongs to `Listing`, `User` (buyer), `User` (seller)

---

## GraphQL (Absinthe)

### Endpoint

- **HTTP:** `POST /api/graphql` — queries and mutations
- **WebSocket:** `ws://host/api/socket` — subscriptions (Phoenix Channels under the hood)

### Schema Overview

| Type | Operations |
|------|-------------|
| **Query** | `user`, `me`, `listing(id)`, `listings(filter)`, `myListings`, `myBids`, `chatRoom(id)`, `notifications` |
| **Mutation** | `login`, `register`, `createListing`, `placeBid`, `confirmReceipt`, `sendMessage`, `readNotification` |
| **Subscription** | `listingUpdated(listingId)`, `newBid(listingId)`, `auctionEnded(listingId)`, `newChatMessage(roomId)` |

### Key Types

```graphql
type User {
  id: ID!
  email: String!
  displayName: String
  avatarUrl: String
  listings: [Listing!]!
}

type Listing {
  id: ID!
  title: String!
  description: String
  startingPrice: Decimal!
  currentPrice: Decimal!
  status: ListingStatus!
  endAt: DateTime!
  seller: User!
  bids: [Bid!]!
  highestBid: Bid
}

type Bid {
  id: ID!
  amount: Decimal!
  user: User!
  listing: Listing!
  insertedAt: DateTime!
}

type ChatRoom {
  id: ID!
  listing: Listing!
  messages: [Message!]!
}

type Message {
  id: ID!
  body: String!
  user: User!
  insertedAt: DateTime!
}
```

### Auth in GraphQL

- **Context** — Resolve current user from session/ Bearer token; add to Absinthe context
- **Secured fields** — Use middleware to require `current_user` for mutations and private queries
- **Guards** — `can_bid?`, `can_chat?`, etc. in resolvers

### Subscriptions

- **`listingUpdated`** — Broadcast when bid placed, auction ends; clients subscribe with `listingId`
- **`newChatMessage`** — Broadcast when message sent; clients subscribe with `roomId`
- **Transport** — Absinthe.Phoenix.Subscription uses Phoenix Channels; WebSocket URL configured in client (Apollo, urql, etc.)

---

## Phoenix Channels

### Listing Channel

- **Topic**: `listing:#{listing_id}`
- **Events**: `new_bid`, `auction_ended`, `bid_outbid`
- **Auth**: verify user can join (public for viewing, auth for bidding)

### Chat Channel

- **Topic**: `chat:#{room_id}`
- **Events**: `new_message`, `typing`, `user_joined`
- **Auth**: only participants (buyer, seller, bidders)

---

## Implementation Phases

### Phase 1 — Foundation (2–3 weeks)

- [ ] Phoenix project setup
- [ ] Absinthe GraphQL setup (`/api/graphql` endpoint)
- [ ] User accounts (phx.gen.auth)
- [ ] GraphQL schema: User, Listing, Bid types; queries and mutations
- [ ] Listings CRUD (via GraphQL + context)
- [ ] Bidding logic (no live yet)
- [ ] Basic UI (HTML/HEEx or SPA consuming GraphQL)

### Phase 2 — Real-time Bidding (1–2 weeks)

- [ ] GraphQL subscriptions: `listingUpdated`, `newBid`, `auctionEnded`
- [ ] ListingChannel (or subscription) broadcasts on bid/end
- [ ] LiveView for listing page with live updates (or SPA with GraphQL subscriptions)
- [ ] Auction end job (Oban)
- [ ] Winner selection logic

### Phase 3 — Payments & Escrow (2–3 weeks)

- [ ] Stripe Connect setup
- [ ] Escrow schema and state machine
- [ ] Payment flow (buyer → escrow)
- [ ] Release flow (escrow → seller)
- [ ] Platform fee and payouts

### Phase 4 — Notifications (1 week)

- [ ] Notification schema and context
- [ ] Oban workers for email delivery
- [ ] In-app notification UI
- [ ] Email templates

### Phase 5 — Live Chat (1–2 weeks)

- [ ] Chat rooms and messages
- [ ] GraphQL ChatRoom, Message types; `sendMessage` mutation; `newChatMessage` subscription
- [ ] ChatChannel (subscription backend)
- [ ] Chat LiveView component (or SPA with subscriptions)
- [ ] Presence

### Phase 6 — Polish (1–2 weeks)

- [ ] Search and filtering
- [ ] User ratings/reviews
- [ ] Dispute flow
- [ ] Admin tools
- [ ] Performance and security review

---

## Security (Detailed)

### Authentication

- **Password hashing** — Use `bcrypt_elixir` (phx.gen.auth default); cost factor 12+
- **Session** — Signed/encrypted cookies; 2-week expiry with "remember me"
- **Email confirmation** — Require before bidding/selling; token expiry 24h
- **Password reset** — Single-use token, 1h expiry
- **Concurrent sessions** — Optional: limit per user; store session IDs in DB

### Authorization

- **Policy module** — e.g. `Bidph.Policies.ListingPolicy` for `can_bid?`, `can_edit?`, `can_release_escrow?`
- **Check before every action** — Bidding (logged in, not own listing, before end time)
- **Escrow release** — Only buyer or admin; never auto-release without explicit confirmation
- **Chat** — Only participants (seller, winning bidder, or all bidders per config)
- **Admin** — Separate role; use `:is_admin` or `roles` array in users

### Input & Injection

- **Ecto changesets** — All user input through validated changesets; cast only allowed fields
- **SQL injection** — Ecto parameterizes by default; avoid raw SQL or sanitize
- **XSS** — Phoenix auto-escapes HEEx; use `raw/1` only when necessary and sanitize
- **File uploads** — Validate MIME type, size; store outside webroot or in object storage; never execute

### Rate Limiting

- **Bids** — Max N bids per user per listing per minute (e.g. 10)
- **API / Stripe** — Throttle payment/API calls per user
- **Login** — Lock after N failed attempts (e.g. 5 in 15 min)
- **Implementation** — `hammer` or custom ETS/cache counter; key = `user_id:action:window`

### Payments & PCI

- **Never store card data** — Use Stripe.js / Elements; tokenize on client
- **Stripe Connect** — Sellers onboard via Stripe OAuth; store only `stripe_account_id`
- **Webhooks** — Verify Stripe webhook signature; idempotent handlers
- **Idempotency** — Use Stripe idempotency keys for payment/refund requests

### HTTPS & Headers

- **Force HTTPS** — `force_ssl` in endpoint; redirect HTTP → HTTPS
- **Security headers** — `plug_secure_headers` or manual: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`
- **Cookies** — `secure: true`, `http_only: true`, `same_site: "Lax"`

### Escrow & Funds

- **Double-check** — Release only when buyer confirms receipt or dispute timeout
- **Audit trail** — Log all escrow state changes and who triggered them
- **Idempotent payouts** — Use Stripe idempotency; handle duplicate webhooks

### Secrets & Config

- **Secrets** — Use `config/runtime.exs` + env vars; never commit secrets
- **Database** — Restrict DB user permissions; use connection pooling
- **Logging** — Never log passwords, tokens, or full card numbers

---

## Suggested Dependencies (mix.exs)

### Core Phoenix

```elixir
{:phoenix, "~> 1.7"},
{:phoenix_live_view, "~> 0.20"},
{:phoenix_html, "~> 4.0"},
{:phoenix_live_reload, "~> 1.2", only: :dev},
{:phoenix_live_dashboard, "~> 0.8"},
```

### Database

```elixir
{:phoenix_ecto, "~> 4.4"},
{:ecto_sql, "~> 3.10"},
{:postgrex, ">= 0.0.0"},
```

### Auth

```elixir
{:bcrypt_elixir, "~> 3.0"},
# Optional OAuth:
{:ueberauth, "~> 0.10"},
{:ueberauth_google, "~> 0.10"},
{:ueberauth_github, "~> 0.8"},
```

### Background Jobs

```elixir
{:oban, "~> 2.14"},
{:oban_web, "~> 2.9"},  # optional dashboard
```

### Payments

```elixir
{:stripity_stripe, "~> 3.0"},
```

### Email

```elixir
{:swoosh, "~> 1.12"},
{:finch, "~> 0.16"},
{:floki, ">= 0.30.0"},  # for HTML email testing
```

### Rate Limiting

```elixir
{:hammer, "~> 6.1"},    # or {:hammer_backend_redis, "~> 6.0"} with Redis
```

### Security Headers

```elixir
{:plug_secure_headers, "~> 0.1"},
```

### File Uploads (listings, avatars)

```elixir
{:ex_aws, "~> 2.4"},
{:ex_aws_s3, "~> 2.4"},
{:sweet_xml, "~> 0.7"},
# Or local: {:waffle, "~> 1.1"} + {:waffle_ecto, "~> 0.0"},
```

### Development & Test

```elixir
{:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
{:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
{:floki, ">= 0.30.0"},
{:phoenix_live_view, "~> 0.20", only: :dev},
{:telemetry_metrics, "~> 1.0"},
{:telemetry_poller, "~> 1.0"},
```

### GraphQL (Absinthe)

```elixir
{:absinthe, "~> 1.7"},
{:absinthe_plug, "~> 1.5"},
{:absinthe_phoenix, "~> 2.0"},   # subscriptions over Phoenix Channels
{:dataloader, "~> 2.0"},         # N+1 prevention
```

### Optional

```elixir
{:cachex, "~> 3.6"},             # caching
{:jason, "~> 1.4"},              # JSON (Phoenix default)
{:gettext, "~> 0.24"},
{:plug_cowboy, "~> 2.6"},
```

---

## Next Steps

1. Run `mix phx.new bidph --live` to create the project
2. Add `absinthe`, `absinthe_plug`, `absinthe_phoenix`, `dataloader` to mix.exs
3. Add GraphQL scope to router: `forward "/api", Absinthe.Plug, schema: BidphWeb.Schema`
4. Add WebSocket for subscriptions: `forward "/api/socket", BidphWeb.ApiSocket`
5. Add `mix phx.gen.auth Accounts User users` for auth
6. Implement GraphQL schema and resolvers alongside contexts
7. Iterate through phases, testing each before moving on
