defmodule BidphWeb.ProfileLive.Show do
  use BidphWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:user, user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="px-4 py-8 sm:px-6 lg:px-8 max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold">Profile</h1>
        <p class="mt-1 text-sm text-base-content/70">{@user.email}</p>

        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-base-300 bg-base-100 p-5">
            <p class="text-xs text-base-content/60">Account</p>
            <p class="mt-2 text-sm">Display name: {@user.display_name || "—"}</p>
            <p class="mt-1 text-sm">Email: {@user.email}</p>
          </div>
          <div class="rounded-xl border border-base-300 bg-base-100 p-5">
            <p class="text-xs text-base-content/60">Quick Links</p>
            <div class="mt-3 flex flex-wrap gap-2">
              <.link href={~p"/my-listings"} class="btn btn-ghost btn-sm">My Listings</.link>
              <.link href={~p"/wallet"} class="btn btn-ghost btn-sm">Wallet</.link>
              <.link href={~p"/payment-methods"} class="btn btn-ghost btn-sm">Payment Methods</.link>
              <.link href={~p"/listings/new"} class="btn btn-primary btn-sm">Upload Product</.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
