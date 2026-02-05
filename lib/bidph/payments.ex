defmodule Bidph.Payments do
  @moduledoc """
  Wallets, payment methods, and bid holds.
  """

  import Ecto.Query, warn: false
  alias Bidph.Repo

  alias Bidph.Accounts.User
  alias Bidph.Listings.Bid
  alias Bidph.Payments.{Wallet, WalletTransaction, PaymentMethod, PaymentHold}
  alias Bidph.Payments.Stripe
  alias Bidph.Notifications

  def ensure_wallet(%User{id: user_id}) do
    Repo.get_by(Wallet, user_id: user_id) ||
      %Wallet{}
      |> Wallet.changeset(%{user_id: user_id, balance: 0, held_balance: 0})
      |> Repo.insert!()
  end

  def get_wallet(%User{id: user_id}) do
    Repo.get_by(Wallet, user_id: user_id)
  end

  def get_active_payment_method(%User{id: user_id}) do
    PaymentMethod
    |> where([pm], pm.user_id == ^user_id and pm.status == "active")
    |> order_by([pm], desc: pm.inserted_at)
    |> Repo.one()
  end

  def list_payment_methods(%User{id: user_id}) do
    PaymentMethod
    |> where([pm], pm.user_id == ^user_id)
    |> order_by([pm], desc: pm.inserted_at)
    |> Repo.all()
  end

  def get_payment_method!(id), do: Repo.get!(PaymentMethod, id)

  def add_payment_method(%User{id: user_id}, attrs) do
    attrs =
      attrs
      |> Map.put("user_id", user_id)
      |> Map.put_new("status", "pending")

    %PaymentMethod{}
    |> PaymentMethod.changeset(attrs)
    |> Repo.insert()
  end

  def add_stripe_payment_method(%User{} = user, payment_method_id) do
    with {:ok, customer_id} <- ensure_stripe_customer(user),
         {:ok, _} <- Stripe.attach_payment_method(payment_method_id, customer_id) do
      add_payment_method(user, %{
        "provider" => "Stripe",
        "method_type" => "card",
        "external_id" => payment_method_id,
        "status" => "pending"
      })
    end
  end

  def ensure_stripe_customer(%User{} = user) do
    if user.stripe_customer_id do
      {:ok, user.stripe_customer_id}
    else
      with {:ok, %{"id" => customer_id}} <- Stripe.create_customer(user.email, %{"user_id" => user.id}) do
        user
        |> Ecto.Changeset.change(stripe_customer_id: customer_id)
        |> Repo.update()
        |> case do
          {:ok, _} -> {:ok, customer_id}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  def top_up_wallet(%User{} = user, amount, provider \\ "bank", reference \\ nil, external_id \\ nil) do
    amount = Decimal.new(to_string(amount))
    wallet = ensure_wallet(user)
    receipt_number = "RCPT-" <> Integer.to_string(System.system_time(:second))

    Repo.transaction(fn ->
      wallet =
        wallet
        |> Wallet.changeset(%{balance: Decimal.add(wallet.balance, amount)})
        |> Repo.update!()

      tx =
        %WalletTransaction{}
        |> WalletTransaction.changeset(%{
          wallet_id: wallet.id,
          amount: amount,
          transaction_type: "top_up",
          provider: provider,
          reference: reference,
          status: "posted",
          receipt_number: receipt_number,
          external_id: external_id
        })
        |> Repo.insert!()

      Notifications.send_topup_receipt(user, tx)

      wallet
    end)
  end

  def create_stripe_topup_intent(%User{} = user, amount) do
    amount = Decimal.new(to_string(amount))

    with {:ok, customer_id} <- ensure_stripe_customer(user),
         {:ok, %{"client_secret" => client_secret}} <-
           Stripe.create_payment_intent(to_cents(amount), "php", customer_id, %{
             "user_id" => user.id,
             "purpose" => "wallet_topup"
           }) do
      {:ok, client_secret}
    end
  end

  defp to_cents(amount) do
    amount
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> String.to_integer()
  end

  def list_wallet_transactions(%User{} = user, limit \\ 10) do
    wallet = get_wallet(user)

    if wallet do
      WalletTransaction
      |> where([t], t.wallet_id == ^wallet.id)
      |> order_by([t], desc: t.inserted_at)
      |> limit(^limit)
      |> Repo.all()
    else
      []
    end
  end

  def verify_payment_method(%PaymentMethod{} = method, external_id \\ nil) do
    method
    |> PaymentMethod.changeset(%{
      status: "active",
      external_id: external_id || method.external_id,
      verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def fail_payment_method(%PaymentMethod{} = method) do
    method
    |> PaymentMethod.changeset(%{status: "failed"})
    |> Repo.update()
  end

  def get_payment_method_by_external_id(external_id) when is_binary(external_id) do
    Repo.get_by(PaymentMethod, external_id: external_id)
  end

  def get_wallet_transaction_by_external_id(external_id) when is_binary(external_id) do
    Repo.get_by(WalletTransaction, external_id: external_id)
  end

  def can_bid?(%User{} = user, amount) do
    amount = Decimal.new(to_string(amount))
    wallet = ensure_wallet(user)
    payment_method = get_active_payment_method(user)

    cond do
      is_nil(payment_method) -> {:error, :no_payment_method}
      Decimal.compare(wallet.balance, amount) != :gt and Decimal.compare(wallet.balance, amount) != :eq ->
        {:error, :no_wallet_funds}
      true -> {:ok, %{wallet: wallet, payment_method: payment_method}}
    end
  end

  def hold_funds_for_bid!(%User{} = user, %Bid{} = bid, amount) do
    amount = Decimal.new(to_string(amount))
    wallet = ensure_wallet(user)
    payment_method = get_active_payment_method(user)

    if is_nil(payment_method) do
      raise "No active payment method"
    end

    if Decimal.compare(wallet.balance, amount) == :lt do
      raise "Insufficient wallet balance"
    end

    wallet =
      wallet
      |> Wallet.changeset(%{
        balance: Decimal.sub(wallet.balance, amount),
        held_balance: Decimal.add(wallet.held_balance, amount)
      })
      |> Repo.update!()

    %WalletTransaction{}
    |> WalletTransaction.changeset(%{
      wallet_id: wallet.id,
      amount: amount,
      transaction_type: "hold",
      status: "posted"
    })
    |> Repo.insert!()

    %PaymentHold{}
    |> PaymentHold.changeset(%{
      user_id: user.id,
      payment_method_id: payment_method.id,
      bid_id: bid.id,
      amount: amount,
      status: "held"
    })
    |> Repo.insert!()
  end

  def release_hold_for_bid(%Bid{id: bid_id}) do
    hold =
      PaymentHold
      |> where([h], h.bid_id == ^bid_id and h.status == "held")
      |> Repo.one()

    if hold do
      Repo.transaction(fn ->
        wallet = Repo.get_by!(Wallet, user_id: hold.user_id)

        wallet
        |> Wallet.changeset(%{
          balance: Decimal.add(wallet.balance, hold.amount),
          held_balance: Decimal.sub(wallet.held_balance, hold.amount)
        })
        |> Repo.update!()

        %WalletTransaction{}
        |> WalletTransaction.changeset(%{
          wallet_id: wallet.id,
          amount: hold.amount,
          transaction_type: "release",
          status: "posted"
        })
        |> Repo.insert!()

        hold
        |> Ecto.Changeset.change(status: "released")
        |> Repo.update!()
      end)
    else
      {:ok, :noop}
    end
  end
end
