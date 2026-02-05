defmodule BidphWeb.WalletLive.TopUp do
  use BidphWeb, :live_view

  alias Bidph.Payments

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    wallet = Payments.ensure_wallet(user)
    transactions = Payments.list_wallet_transactions(user, 8)

    {:ok,
     socket
     |> assign(:page_title, "Wallet")
     |> assign(:wallet, wallet)
     |> assign(:transactions, transactions)
     |> assign(:stripe_intent, nil)
     |> assign(:stripe_error, nil)}
  end

  @impl true
  def handle_event("top_up", %{"amount" => amount, "provider" => provider}, socket) do
    user = socket.assigns.current_scope.user

    cond do
      amount == "" ->
        {:noreply, put_flash(socket, :error, "Enter a top-up amount")}

      true ->
        case Payments.top_up_wallet(user, amount, provider) do
          {:ok, wallet} ->
            transactions = Payments.list_wallet_transactions(user, 8)

            {:noreply,
             socket
             |> put_flash(:info, "Top-up successful")
             |> assign(:wallet, wallet)
             |> assign(:transactions, transactions)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Top-up failed")}
        end
    end
  end

  @impl true
  def handle_event("stripe_intent", %{"amount" => amount}, socket) do
    user = socket.assigns.current_scope.user

    case Payments.create_stripe_topup_intent(user, amount) do
      {:ok, client_secret} ->
        {:noreply,
         socket
         |> assign(:stripe_intent, client_secret)
         |> push_event("stripe_intent", %{client_secret: client_secret})}

      {:error, reason} ->
        {:noreply, assign(socket, :stripe_error, inspect(reason))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8 max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold">Wallet</h1>
        <p class="mt-1 text-sm text-base-content/70">Top up to place bids.</p>

        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs text-base-content/60">Available Balance</p>
            <p class="text-2xl font-bold">₱{Decimal.to_string(@wallet.balance)}</p>
          </div>
          <div class="rounded-xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs text-base-content/60">Held Balance</p>
            <p class="text-2xl font-bold">₱{Decimal.to_string(@wallet.held_balance)}</p>
          </div>
        </div>

        <div class="mt-8 rounded-xl border border-base-300 bg-base-100 p-6">
          <h2 class="text-lg font-semibold">Top Up</h2>
          <.form for={%{}} phx-submit="top_up" class="mt-4 grid gap-4 sm:grid-cols-3">
            <div class="sm:col-span-2">
              <label class="label">Amount (₱)</label>
              <input name="amount" type="number" min="1" step="0.01" class="input input-bordered w-full" />
            </div>
            <div>
              <label class="label">Provider</label>
              <select name="provider" class="select select-bordered w-full">
                <option value="gcash">GCash</option>
                <option value="maya">Maya</option>
                <option value="bank">Bank Transfer</option>
              </select>
            </div>
            <div class="sm:col-span-3">
              <button type="submit" class="btn btn-primary">Top Up Wallet</button>
            </div>
          </.form>
        </div>

        <div id="stripe-topup" class="mt-6 rounded-xl border border-base-300 bg-base-100 p-6" phx-hook="StripeTopup">
          <h2 class="text-lg font-semibold">Stripe Top-up Intent</h2>
          <p class="mt-1 text-sm text-base-content/60">
            Create a PaymentIntent and complete it with Stripe.js.
          </p>
          <.form for={%{}} phx-submit="stripe_intent" class="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label class="label">Amount (₱)</label>
              <input name="amount" type="number" min="1" step="0.01" class="input input-bordered w-full" />
            </div>
            <div class="flex items-end">
              <button type="submit" class="btn btn-primary">Create Stripe Intent</button>
            </div>
          </.form>
          <div class="mt-4">
            <label class="label">Card Details</label>
            <div data-stripe-card class="rounded-lg border border-base-300 bg-base-100 p-3"></div>
          </div>
          <p data-stripe-status class="mt-2 text-xs text-base-content/70"></p>
          <p :if={@stripe_error} class="mt-2 text-xs text-error">{@stripe_error}</p>
        </div>

        <div class="mt-8">
          <h2 class="text-lg font-semibold">Recent Transactions</h2>
          <ul class="mt-3 space-y-2">
            <li :for={tx <- @transactions} class="flex items-center justify-between rounded-lg border border-base-300 bg-base-100 px-4 py-3">
              <div>
                <p class="text-sm font-medium capitalize">{tx.transaction_type}</p>
                <p class="text-xs text-base-content/60">{tx.provider || "—"}</p>
                <p class="text-xs text-base-content/60">Receipt: {tx.receipt_number || "—"}</p>
              </div>
              <div class="text-right">
                <p class="text-sm font-semibold">₱{Decimal.to_string(tx.amount)}</p>
                <p class="text-xs text-base-content/60">{tx.status}</p>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
