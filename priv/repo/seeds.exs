# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# --- Super admin ---
#
# Set in .env (copy .env.example to .env) or pass on the command line:
#
#   FIRST_SUPER_ADMIN_EMAIL=admin@example.com
#   FIRST_SUPER_ADMIN_PASSWORD=your-secure-password  (min 12 chars, only to create new user)
#
# Then run: mix ecto.reset  or  mix run priv/repo/seeds.exs
#

defmodule Dotenv do
  def load do
    path = Path.join(File.cwd!(), ".env")

    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split(~r/\r?\n/, trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, "=", parts: 2) do
          [key, value] ->
            key = key |> String.trim() |> String.trim_leading("export ")
            value = value |> String.trim() |> trim_quotes()
            Map.put(acc, key, value)

          _ ->
            acc
        end
      end)
    else
      %{}
    end
  end

  defp trim_quotes(s) do
    s
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
  end
end

import Ecto.Query
alias Bidph.Repo
alias Bidph.Accounts
alias Bidph.Accounts.User
alias Bidph.Listings
alias Bidph.Payments

# Load .env from project root (env vars still override)
env = Dotenv.load()

if email = env["FIRST_SUPER_ADMIN_EMAIL"] || System.get_env("FIRST_SUPER_ADMIN_EMAIL") do
  password = env["FIRST_SUPER_ADMIN_PASSWORD"] || System.get_env("FIRST_SUPER_ADMIN_PASSWORD")

  case Repo.get_by(User, email: email) do
    nil ->
      if password && byte_size(password) >= 12 do
        attrs = %{
          "email" => email,
          "password" => password,
          "password_confirmation" => password
        }

        case Accounts.create_user_with_password(attrs, confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second), is_super_admin: true) do
          {:ok, user} ->
            IO.puts("Created super-admin #{user.email}. Log in at /users/log-in with this email and password.")

          {:error, changeset} ->
            IO.puts("Could not create user: #{inspect(Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end))}")
        end
      else
        IO.puts(
          "No user with email #{email}. Set FIRST_SUPER_ADMIN_PASSWORD (min 12 chars) to create one, or register that email first and run seeds again with only FIRST_SUPER_ADMIN_EMAIL."
        )
      end

    user ->
      if user.is_super_admin do
        IO.puts("#{email} is already a super-admin.")
      else
        user
        |> Ecto.Changeset.change(is_super_admin: true)
        |> Repo.update!()
        IO.puts("Promoted #{email} to super-admin.")
      end
  end
end

# --- Seed listings (featured + hot auctions) ---
#
# Ensure at least one user exists (e.g. register first or use super-admin above),
# then run: mix run priv/repo/seeds.exs
#
user = Repo.one(from u in User, limit: 1)

if user do
  # Ensure wallet + payment method for bidding demos
  wallet = Payments.ensure_wallet(user)

  if Decimal.compare(wallet.balance, 0) == :eq do
    Payments.top_up_wallet(user, 100_000, "gcash", "seed-topup")
  end

  if is_nil(Payments.get_active_payment_method(user)) do
    Payments.add_payment_method(user, %{
      "provider" => "GCash",
      "method_type" => "gcash",
      "last4" => "1234",
      "status" => "active",
      "verified_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  now = DateTime.utc_now() |> DateTime.truncate(:second)
  base_end = DateTime.add(now, 48, :hour)

  mock_listings = [
    %{
      "title" => "1965 Vintage Chronograph",
      "description" => "Rare collector's piece with original documentation. Swiss made, excellent condition.",
      "starting_price" => "45000",
      "end_at" => base_end,
      "category" => "Watches"
    },
    %{
      "title" => "Abstract Geometric Composition",
      "description" => "Mid-century abstract piece by a noted artist.",
      "starting_price" => "12500",
      "end_at" => DateTime.add(base_end, 1, :hour),
      "category" => "Art"
    },
    %{
      "title" => "1962 Ferrari 250 GT California Spider",
      "description" => "Classic Ferrari in restored condition.",
      "starting_price" => "875000",
      "end_at" => DateTime.add(base_end, 2, :hour),
      "category" => "Cars"
    },
    %{
      "title" => "Victorian Diamond Necklace, c.1890",
      "description" => "Antique necklace with original setting.",
      "starting_price" => "34000",
      "end_at" => DateTime.add(base_end, 3, :hour),
      "category" => "Jewelry"
    },
    %{
      "title" => "Louis XV Carved Armchair, 18th Century",
      "description" => "Period furniture, excellent condition.",
      "starting_price" => "8500",
      "end_at" => DateTime.add(base_end, 4, :hour),
      "category" => "Furniture"
    }
  ]

  for attrs <- mock_listings do
    case Listings.create_listing(user, attrs) do
      {:ok, listing} ->
        IO.puts("Created listing: #{listing.title} (id: #{listing.id})")

      {:error, changeset} ->
        IO.puts("Skipped listing #{attrs["title"]}: #{inspect(Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end))}")
    end
  end
else
  IO.puts("No user in DB. Register one or set FIRST_SUPER_ADMIN_EMAIL/FIRST_SUPER_ADMIN_PASSWORD and run seeds to create listings.")
end
