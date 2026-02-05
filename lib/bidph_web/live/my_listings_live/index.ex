defmodule BidphWeb.MyListingsLive.Index do
  use BidphWeb, :live_view

  alias Bidph.Listings

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    listings = Listings.list_listings_by_user(user)

    {:ok,
     socket
     |> assign(:page_title, "My Listings")
     |> assign(:user, user)
     |> assign(:listings, listings)}
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id, "status" => status}, socket) do
    user = socket.assigns.current_scope.user
    listing = Listings.get_listing!(id)

    if listing.user_id == user.id do
      next_status = if status == "active", do: "paused", else: "active"

      case Listings.set_listing_status(listing, next_status) do
        {:ok, _} ->
          listings = Listings.list_listings_by_user(user)
          {:noreply, assign(socket, :listings, listings)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update listing status")}
      end
    else
      {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8 max-w-5xl mx-auto">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold">My Listings</h1>
            <p class="mt-1 text-sm text-base-content/70">Manage your posted items.</p>
          </div>
          <.link href={~p"/listings/new"} class="btn btn-primary">Upload Product</.link>
        </div>

        <div class="mt-8">
          <ul class="space-y-3">
            <li :for={listing <- @listings} class="flex flex-col gap-3 rounded-xl border border-base-300 bg-base-100 p-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <.link href={~p"/listings/#{listing.id}"} class="font-semibold hover:underline">{listing.title}</.link>
                <p class="text-xs text-base-content/60">Status: {listing.status}</p>
              </div>
              <div class="flex items-center gap-2">
                <.link href={~p"/listings/#{listing.id}"} class="btn btn-ghost btn-sm">Open</.link>
                <button
                  :if={listing.status in ["active", "paused"]}
                  class="btn btn-outline btn-sm"
                  phx-click="toggle_status"
                  phx-value-id={listing.id}
                  phx-value-status={listing.status}
                >
                  <%= if listing.status == "active", do: "Pause Bidding", else: "Enable Bidding" %>
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
