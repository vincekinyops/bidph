defmodule BidphWeb.Webhooks.PaymentController do
  use BidphWeb, :controller

  alias Bidph.Accounts
  alias Bidph.Payments

  def create(conn, %{"event" => event, "data" => data}) do
    with :ok <- verify_secret(conn) do
      case event do
        "payment_method.verified" ->
          external_id = data["external_id"]

          with %{} = method <- Payments.get_payment_method_by_external_id(external_id),
               {:ok, method} <- Payments.verify_payment_method(method, external_id) do
            user = Accounts.get_user!(method.user_id)
            Bidph.Notifications.send_payment_method_verified(user, method.provider)
            json(conn, %{status: "ok"})
          else
            _ -> json(conn, %{status: "ignored"})
          end

        "wallet.topup.succeeded" ->
          user_id = data["user_id"]
          amount = data["amount"]
          provider = data["provider"] || "bank"
          external_id = data["external_id"]

          if Payments.get_wallet_transaction_by_external_id(external_id) do
            json(conn, %{status: "duplicate"})
          else
            user = Accounts.get_user!(user_id)
            {:ok, _} = Payments.top_up_wallet(user, amount, provider, external_id, external_id)
            json(conn, %{status: "ok"})
          end

        _ ->
          json(conn, %{status: "ignored"})
      end
    else
      _ -> send_resp(conn, 401, "unauthorized")
    end
  end

  def create(conn, _params) do
    send_resp(conn, 400, "invalid payload")
  end

  defp verify_secret(conn) do
    secret = System.get_env("PAYMENTS_WEBHOOK_SECRET")

    case get_req_header(conn, "x-webhook-secret") do
      [^secret] when is_binary(secret) and byte_size(secret) > 0 -> :ok
      _ -> {:error, :unauthorized}
    end
  end
end
