defmodule BidphWeb.PaymentMethodsLive.Index do
  use BidphWeb, :live_view

  alias Bidph.Payments

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    methods = Payments.list_payment_methods(user)

    {:ok,
     socket
     |> assign(:page_title, "Payment Methods")
     |> assign(:methods, methods)
     |> assign(:stripe_error, nil)}
  end

  @impl true
  def handle_event("add_method", params, socket) do
    user = socket.assigns.current_scope.user

    case Payments.add_payment_method(user, params) do
      {:ok, _method} ->
        methods = Payments.list_payment_methods(user)

        {:noreply,
         socket
         |> put_flash(:info, "Payment method added")
         |> assign(:methods, methods)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not add payment method")}
    end
  end

  @impl true
  def handle_event("verify_method", %{"id" => id}, socket) do
    method = Payments.get_payment_method!(id)

    case Payments.verify_payment_method(method, "manual-#{System.system_time(:second)}") do
      {:ok, method} ->
        Bidph.Notifications.send_payment_method_verified(socket.assigns.current_scope.user, method.provider)
        methods = Payments.list_payment_methods(socket.assigns.current_scope.user)
        {:noreply, assign(socket, :methods, methods)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Verification failed")}
    end
  end

  @impl true
  def handle_event("add_stripe_method", %{"payment_method_id" => payment_method_id}, socket) do
    user = socket.assigns.current_scope.user

    case Payments.add_stripe_payment_method(user, payment_method_id) do
      {:ok, _method} ->
        methods = Payments.list_payment_methods(user)
        {:noreply, assign(socket, :methods, methods)}

      {:error, reason} ->
        {:noreply, assign(socket, :stripe_error, inspect(reason))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8 max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold">Payment Methods</h1>
        <p class="mt-1 text-sm text-base-content/70">Add a payment method before bidding.</p>

        <div class="mt-6 rounded-xl border border-base-300 bg-base-100 p-6">
          <h2 class="text-lg font-semibold">Add Payment Method</h2>
          <.form for={%{}} phx-submit="add_method" class="mt-4 grid gap-4 sm:grid-cols-3">
            <div>
              <label class="label">Provider</label>
              <input name="provider" type="text" placeholder="GCash / Maya / Bank" class="input input-bordered w-full" />
            </div>
            <div>
              <label class="label">Type</label>
              <select name="method_type" class="select select-bordered w-full">
                <option value="gcash">GCash</option>
                <option value="maya">Maya</option>
                <option value="bank">Bank</option>
                <option value="card">Card</option>
              </select>
            </div>
            <div>
              <label class="label">Last 4 (optional)</label>
              <input name="last4" type="text" maxlength="4" class="input input-bordered w-full" />
            </div>
            <div class="sm:col-span-3">
              <button type="submit" class="btn btn-primary">Add Method</button>
            </div>
          </.form>
        </div>

        <div id="stripe-payment-method" class="mt-6 rounded-xl border border-base-300 bg-base-100 p-6" phx-hook="StripePaymentMethod">
          <h2 class="text-lg font-semibold">Stripe Payment Method</h2>
          <p class="mt-1 text-sm text-base-content/60">
            Use a Stripe PaymentMethod ID (e.g. pm_123...) from Stripe.js.
          </p>
          <div class="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label class="label">Card Details</label>
              <div data-stripe-card class="rounded-lg border border-base-300 bg-base-100 p-3"></div>
            </div>
            <div class="flex items-end">
              <button data-stripe-action="create-payment-method" class="btn btn-primary">Attach via Stripe</button>
            </div>
          </div>
          <p data-stripe-error class="mt-2 text-xs text-error">{@stripe_error}</p>
        </div>

        <div class="mt-8">
          <h2 class="text-lg font-semibold">Your Methods</h2>
          <ul class="mt-3 space-y-2">
            <li :for={method <- @methods} class="flex items-center justify-between rounded-lg border border-base-300 bg-base-100 px-4 py-3">
              <div>
                <p class="text-sm font-medium">{method.provider}</p>
                <p class="text-xs text-base-content/60 capitalize">{method.method_type}</p>
                <p class="text-xs text-base-content/60 capitalize">Status: {method.status}</p>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-xs text-base-content/60">{method.last4 || "—"}</span>
                <span :if={method.external_id} class="text-xs text-base-content/60">{method.external_id}</span>
                <button
                  :if={method.status == "pending"}
                  class="btn btn-ghost btn-xs"
                  phx-click="verify_method"
                  phx-value-id={method.id}
                >
                  Verify
                </button>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
