defmodule BidphWeb.AdminLive.Dashboard do
  use BidphWeb, :live_view

  alias Bidph.Accounts
  alias Bidph.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Admin")
      |> assign(:users, Accounts.list_users())
      |> assign(:listings_count, count_listings())
      |> assign(:users_count, count_users())

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_super_admin", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.user

    unless User.super_admin?(current_user) do
      {:noreply, put_flash(socket, :error, "Not authorized")}
    else
      user = Accounts.get_user!(id)

      case Accounts.set_super_admin(user, !user.is_super_admin) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Updated super admin status.")
           |> assign(:users, Accounts.list_users())}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <.link navigate={~p"/"} class="text-sm link link-hover mb-4 inline-block">← Back</.link>

      <h1 class="text-2xl font-bold">Super Admin</h1>
      <p class="mt-1 text-sm text-base-content/70">Manage users and view overview.</p>

      <div class="mt-6 grid gap-4 sm:grid-cols-2">
        <div class="rounded-box border border-base-300 bg-base-200 p-4">
          <p class="text-sm text-base-content/70">Total users</p>
          <p class="text-2xl font-semibold"><%= @users_count %></p>
        </div>
        <div class="rounded-box border border-base-300 bg-base-200 p-4">
          <p class="text-sm text-base-content/70">Total listings</p>
          <p class="text-2xl font-semibold"><%= @listings_count %></p>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-lg font-semibold">Users</h2>
        <div class="mt-2 overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Email</th>
                <th>Display name</th>
                <th>Super admin</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              <.user_row :for={user <- @users} user={user} current_user={@current_scope.user} />
            </tbody>
          </table>
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  attr :user, User, required: true
  attr :current_user, User, required: true

  defp user_row(assigns) do
    ~H"""
    <tr>
      <td><%= @user.email %></td>
      <td><%= @user.display_name || "—" %></td>
      <td>
        <.button
          :if={@current_user.id != @user.id}
          phx-click="toggle_super_admin"
          phx-value-id={@user.id}
          class={if @user.is_super_admin, do: "btn btn-error btn-sm", else: "btn btn-ghost btn-sm"}
        >
          <%= if @user.is_super_admin, do: "Revoke admin", else: "Make super admin" %>
        </.button>
        <span :if={@current_user.id == @user.id} class="badge badge-primary">You</span>
      </td>
      <td><%= Calendar.strftime(@user.inserted_at, "%Y-%m-%d") %></td>
    </tr>
    """
  end

  defp count_users do
    Bidph.Repo.aggregate(Bidph.Accounts.User, :count, :id)
  end

  defp count_listings do
    Bidph.Repo.aggregate(Bidph.Listings.Listing, :count, :id)
  end
end
