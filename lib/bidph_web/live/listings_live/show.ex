defmodule BidphWeb.ListingsLive.Show do
  use BidphWeb, :live_view

  alias Bidph.Listings
  alias Bidph.Listings.Bid

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    listing = Listings.get_listing!(id)

    socket =
      socket
      |> assign(:page_title, listing.title)
      |> assign(:listing, listing)
      |> assign(:bid_amount, "")
      |> assign(:bid_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("place_bid", %{"amount" => amount}, socket) do
    current_scope = socket.assigns.current_scope
    listing = socket.assigns.listing

    cond do
      is_nil(current_scope) or is_nil(current_scope.user) ->
        {:noreply,
         socket
         |> put_flash(:error, "You must be logged in to bid")
         |> assign(:bid_error, "Log in to bid")}

      amount == "" or amount =~ ~r/^\s*$/ ->
        {:noreply,
         socket
         |> assign(:bid_error, "Enter a bid amount")
         |> assign(:bid_amount, amount)}

      true ->
        case Listings.place_bid(listing, current_scope.user, amount) do
          {:ok, _bid} ->
            listing = Listings.get_listing!(listing.id)

            {:noreply,
             socket
             |> put_flash(:info, "Bid placed successfully!")
             |> assign(:listing, listing)
             |> assign(:bid_amount, "")
             |> assign(:bid_error, nil)}

          {:error, reason} ->
            error_msg =
              case reason do
                :cannot_bid_on_own_listing -> "Cannot bid on your own listing"
                :listing_not_active -> "Listing is not active"
                :auction_ended -> "Auction has ended"
                :bid_too_low -> "Bid must be higher than current price"
                _ -> "Could not place bid"
              end

            {:noreply,
             socket
             |> assign(:bid_error, error_msg)
             |> assign(:bid_amount, amount)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8">
        <.link navigate={~p"/listings"} class="text-sm link link-hover mb-4 inline-block">
          ← Back to listings
        </.link>

        <div class="grid gap-8 lg:grid-cols-2">
          <div>
            <h1 class="text-3xl font-bold">{@listing.title}</h1>
            <p class="mt-2 text-base-content/70">{@listing.description}</p>
            <div class="mt-4 flex gap-4 text-sm">
              <span>Category: {@listing.category || "—"}</span>
              <span>Ends: {Calendar.strftime(@listing.end_at, "%Y-%m-%d %H:%M UTC")}</span>
            </div>
          </div>

          <div class="rounded-box border border-base-300 bg-base-200 p-6">
            <div class="text-2xl font-mono font-bold text-primary">
              ${Decimal.to_string(@listing.current_price)}
            </div>
            <p class="mt-1 text-sm text-base-content/60">Current bid</p>

            <div :if={@listing.status == "active"} class="mt-6">
              <.form
                :if={
                  @current_scope && @current_scope.user && @listing.user_id != @current_scope.user.id
                }
                for={%{}}
                phx-submit="place_bid"
                class="space-y-4"
              >
                <div>
                  <label for="bid_amount" class="label">Your bid</label>
                  <input
                    type="number"
                    name="amount"
                    id="bid_amount"
                    value={@bid_amount}
                    step="0.01"
                    min={Decimal.to_string(@listing.current_price)}
                    class="input input-bordered w-full"
                    phx-debounce="300"
                  />
                  <p :if={@bid_error} class="mt-1 text-sm text-error">{@bid_error}</p>
                </div>
                <button type="submit" class="btn btn-primary">Place Bid</button>
              </.form>
              <p :if={!@current_scope || !@current_scope.user} class="mt-4 text-sm">
                <.link navigate={~p"/users/log-in"} class="link link-primary">Log in</.link> to bid
              </p>
              <p
                :if={
                  @current_scope && @current_scope.user && @listing.user_id == @current_scope.user.id
                }
                class="mt-4 text-sm text-base-content/60"
              >
                You cannot bid on your own listing
              </p>
            </div>

            <div class="mt-6">
              <h3 class="font-semibold">Bid History</h3>
              <ul class="mt-2 space-y-1">
                <.bid_item :for={bid <- @listing.bids} bid={bid} />
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :bid, Bid, required: true

  defp bid_item(assigns) do
    ~H"""
    <li class="flex justify-between text-sm">
      <span>{@bid.user.email}</span>
      <span class="font-mono">${Decimal.to_string(@bid.amount)}</span>
    </li>
    """
  end
end
