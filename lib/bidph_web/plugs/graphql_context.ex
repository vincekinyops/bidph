defmodule BidphWeb.Plugs.GraphQLContext do
  @moduledoc """
  Puts the current user (from session) into the Absinthe context.
  """

  import Plug.Conn
  alias Bidph.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_current_user(conn)
    Absinthe.Plug.put_options(conn, context: %{current_user: user})
  end

  defp get_current_user(conn) do
    with token when is_binary(token) <- get_session(conn, :user_token),
         {user, _} <- Accounts.get_user_by_session_token(token) do
      user
    else
      _ -> nil
    end
  end
end
