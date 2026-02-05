defmodule BidphWeb.UserAuthLive do
  @moduledoc """
  On-mount hook for LiveView to assign current_scope from session.
  """

  import Phoenix.Component
  alias Bidph.Accounts
  alias Bidph.Accounts.Scope

  def on_mount(:default, _params, session, socket) do
    current_scope = load_current_scope(session)
    {:cont, assign(socket, current_scope: current_scope)}
  end

  defp load_current_scope(session) do
    token = session["user_token"] || session[:user_token]

    case token do
      nil ->
        nil

      token when is_binary(token) ->
        case Accounts.get_user_by_session_token(token) do
          {user, _token_inserted_at} -> Scope.for_user(user)
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
