# Bidph

## Running with Docker

```bash
docker compose up --build
```

App: http://localhost:4000  
GraphiQL: http://localhost:4000/graphiql

PostgreSQL data persists in a Docker volume.

## Running locally

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## PostgreSQL only (for local dev)

```bash
docker compose up db -d
```

Then run `mix phx.server` locally with `DATABASE_URL=ecto://postgres:postgres@localhost/bidph_dev`.

## Super admin

You can create or promote a super-admin **without using the registration page**, by running seeds.

**Using a `.env` file (recommended)**  
Copy the example and edit with your values:

```bash
cp .env.example .env
# Edit .env and set FIRST_SUPER_ADMIN_EMAIL and (optionally) FIRST_SUPER_ADMIN_PASSWORD
```

Then run `mix ecto.reset` or `mix run priv/repo/seeds.exs`. Seeds read from `.env` automatically (and `.env` is gitignored).

**Option A – Create super-admin in one step**  
Set both in `.env` or on the command line. Creates a new user; they log in at `/users/log-in` with **email + password**.

- `FIRST_SUPER_ADMIN_EMAIL=admin@example.com`
- `FIRST_SUPER_ADMIN_PASSWORD=your-secure-password-12chars` (min 12 characters)

**Option B – Promote an existing user**  
Set only `FIRST_SUPER_ADMIN_EMAIL` in `.env` (no password). User must already exist.

**Revoking / removing a super-admin**

- **From the app:** Log in as another super-admin → **Admin** → find the user → click **Revoke admin**.
- **From the database (e.g. you’re the only admin):** In IEx or a script, demote the user:

  ```elixir
  user = Bidph.Accounts.get_user_by_email("that@example.com")
  Bidph.Accounts.set_super_admin(user, false)
  ```

  Or run a one-off: `mix run -e 'Bidph.Accounts.get_user_by_email("that@example.com") |> then(fn u -> u && Bidph.Accounts.set_super_admin(u, false) end)'`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
