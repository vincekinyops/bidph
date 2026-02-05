defmodule BidphWeb.ListingsLive.Index do
  use BidphWeb, :live_view

  alias Bidph.Listings

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Listings")
      |> assign(:listings, Listings.list_listings())
      |> assign(:listing_changeset, nil)
      |> assign(:form, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listings")
    |> assign(:listing_changeset, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Listing")
    |> assign(:listing_changeset, Listings.Listing.changeset(%Listings.Listing{}, %{}))
    |> assign(:form, to_form(Listings.Listing.changeset(%Listings.Listing{}, %{})))
  end

  @impl true
  def handle_event("save_listing", %{"listing" => params}, socket) do
    current_scope = socket.assigns.current_scope

    if current_scope && current_scope.user do
      end_at = parse_end_at(params["end_at"])

      attrs = %{
        "title" => params["title"],
        "description" => params["description"],
        "starting_price" => params["starting_price"],
        "reserve_price" => params["reserve_price"],
        "end_at" => end_at,
        "category" => params["category"]
      }

      case Listings.create_listing(current_scope.user, attrs) do
        {:ok, _listing} ->
          {:noreply,
           socket
           |> put_flash(:info, "Listing created!")
           |> push_navigate(to: ~p"/listings")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:listing_changeset, changeset)
           |> assign(:form, to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be logged in to create a listing")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  defp parse_end_at(nil), do: nil
  defp parse_end_at(""), do: nil

  defp parse_end_at(str) when is_binary(str) do
    str = if String.ends_with?(str, ":00"), do: str, else: str <> ":00"

    case NaiveDateTime.from_iso8601(str) do
      {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8">
        <div class="sm:flex sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-bold">Active Auctions</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Browse and bid on items.
            </p>
          </div>
          <.link
            :if={@current_scope && @current_scope.user}
            patch={~p"/listings/new"}
            class="btn btn-primary"
          >
            New Listing
          </.link>
        </div>

        <.form
          :if={@live_action == :new}
          for={@form}
          phx-submit="save_listing"
          class="mt-8 rounded-box border border-base-300 bg-base-200 p-6"
        >
          <h2 class="text-lg font-semibold mb-4">Create New Listing</h2>
          <div class="space-y-4">
            <div>
              <label class="label">Title</label>
              <input
                type="text"
                name="listing[title]"
                value={@form[:title].value}
                class="input input-bordered w-full"
                required
              />
            </div>
            <div>
              <label class="label">Description</label>
              <textarea name="listing[description]" class="textarea textarea-bordered w-full" rows="3">{@form[:description].value}</textarea>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="label">Starting Price ($)</label>
                <input
                  type="number"
                  name="listing[starting_price]"
                  value={@form[:starting_price].value}
                  step="0.01"
                  min="0"
                  class="input input-bordered w-full"
                  required
                />
              </div>
              <div>
                <label class="label">Reserve Price ($, optional)</label>
                <input
                  type="number"
                  name="listing[reserve_price]"
                  value={@form[:reserve_price].value}
                  step="0.01"
                  min="0"
                  class="input input-bordered w-full"
                />
              </div>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="label">End Date & Time (YYYY-MM-DDTHH:MM)</label>
                <input
                  type="datetime-local"
                  name="listing[end_at]"
                  class="input input-bordered w-full"
                  required
                />
              </div>
              <div>
                <label class="label">Category</label>
                <input
                  type="text"
                  name="listing[category]"
                  value={@form[:category].value}
                  class="input input-bordered w-full"
                />
              </div>
            </div>
            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">Create Listing</button>
              <.link patch={~p"/listings"} class="btn btn-ghost">Cancel</.link>
            </div>
          </div>
        </.form>

        <div :if={@live_action == :index} class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.listing_card
            :for={listing <- @listings}
            listing={listing}
            current_scope={@current_scope}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :listing, Bidph.Listings.Listing, required: true
  attr :current_scope, :map, default: nil

  defp listing_card(assigns) do
    ~H"""
    <.link navigate={~p"/listings/#{@listing.id}"} class="block">
      <div class="rounded-box border border-base-300 bg-base-100 p-4 shadow-sm transition hover:border-primary hover:shadow-md">
        <h3 class="font-semibold">{@listing.title}</h3>
        <p class="mt-1 text-sm text-base-content/70 line-clamp-2">
          {@listing.description || "No description"}
        </p>
        <div class="mt-3 flex items-center justify-between">
          <span class="font-mono font-medium text-primary">
            ${Decimal.to_string(@listing.current_price)}
          </span>
          <span class="text-xs text-base-content/60">
            Ends {Calendar.strftime(@listing.end_at, "%b %d, %H:%M")}
          </span>
        </div>
      </div>
    </.link>
    """
  end
end
