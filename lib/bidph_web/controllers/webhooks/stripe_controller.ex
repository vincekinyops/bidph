defmodule BidphWeb.Webhooks.StripeController do
  use BidphWeb, :controller

  alias Bidph.Accounts
  alias Bidph.Payments
  alias Bidph.Notifications

  def create(conn, %{"type" => type, "data" => %{"object" => object}}) do
    with :ok <- verify_signature(conn) do
      case type do
        "payment_method.attached" ->
          handle_payment_method_attached(conn, object)

        "setup_intent.succeeded" ->
          handle_setup_intent(conn, object)

        "payment_intent.succeeded" ->
          handle_payment_intent(conn, object)

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

  defp handle_payment_method_attached(conn, %{"id" => pm_id} = object) do
    case Payments.get_payment_method_by_external_id(pm_id) do
      nil ->
        json(conn, %{status: "ignored"})

      method ->
        {:ok, method} = Payments.verify_payment_method(method, pm_id)
        user = Accounts.get_user!(method.user_id)
        Notifications.send_payment_method_verified(user, object["card"]["brand"] || "Stripe")
        json(conn, %{status: "ok"})
    end
  end

  defp handle_setup_intent(conn, %{"payment_method" => pm_id}) do
    case Payments.get_payment_method_by_external_id(pm_id) do
      nil ->
        json(conn, %{status: "ignored"})

      method ->
        {:ok, method} = Payments.verify_payment_method(method, pm_id)
        user = Accounts.get_user!(method.user_id)
        Notifications.send_payment_method_verified(user, method.provider)
        json(conn, %{status: "ok"})
    end
  end

  defp handle_payment_intent(conn, %{"id" => pi_id, "amount_received" => amount_cents, "metadata" => metadata}) do
    user_id = metadata["user_id"]
    provider = metadata["provider"] || "stripe"

    if Payments.get_wallet_transaction_by_external_id(pi_id) do
      json(conn, %{status: "duplicate"})
    else
      user = Accounts.get_user!(user_id)
      amount = Decimal.new(to_string(amount_cents)) |> Decimal.div(100)
      {:ok, _} = Payments.top_up_wallet(user, amount, provider, pi_id, pi_id)
      json(conn, %{status: "ok"})
    end
  end

  defp verify_signature(conn) do
    secret = System.get_env("STRIPE_WEBHOOK_SECRET")
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    payload = conn.assigns[:raw_body] || ""

    cond do
      is_nil(secret) or secret == "" -> {:error, :missing_secret}
      is_nil(signature) -> {:error, :missing_signature}
      valid_signature?(signature, payload, secret) -> :ok
      true -> {:error, :invalid_signature}
    end
  end

  defp valid_signature?(header, payload, secret) do
    with {:ok, timestamp, signatures} <- parse_stripe_signature(header),
         true <- within_tolerance?(timestamp, 300) do
      signed_payload = "#{timestamp}.#{payload}"
      expected =
        :crypto.mac(:hmac, :sha256, secret, signed_payload)
        |> Base.encode16(case: :lower)

      Enum.any?(signatures, fn sig -> sig == expected end)
    else
      _ -> false
    end
  end

  defp parse_stripe_signature(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(fn part -> String.split(part, "=", parts: 2) end)

    timestamp =
      parts
      |> Enum.find_value(fn
        ["t", value] -> value
        _ -> nil
      end)

    signatures =
      parts
      |> Enum.filter(fn
        ["v1", _] -> true
        _ -> false
      end)
      |> Enum.map(fn ["v1", value] -> value end)

    case Integer.parse(to_string(timestamp || "")) do
      {t, _} -> {:ok, t, signatures}
      _ -> {:error, :invalid_header}
    end
  end

  defp within_tolerance?(timestamp, tolerance_sec) do
    now = System.system_time(:second)
    abs(now - timestamp) <= tolerance_sec
  end
end
