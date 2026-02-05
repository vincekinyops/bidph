defmodule Bidph.Payments.Stripe do
  @moduledoc """
  Minimal Stripe client for wallet top-ups and payment methods.
  """

  @base_url "https://api.stripe.com"

  def create_customer(email, metadata \\ %{}) do
    body = %{"email" => email, "metadata" => metadata}
    request(:post, "/v1/customers", body)
  end

  def attach_payment_method(payment_method_id, customer_id) do
    body = %{"customer" => customer_id}
    request(:post, "/v1/payment_methods/#{payment_method_id}/attach", body)
  end

  def create_payment_intent(amount_cents, currency, customer_id, metadata \\ %{}) do
    body = %{
      "amount" => amount_cents,
      "currency" => currency,
      "customer" => customer_id,
      "metadata" => metadata,
      "automatic_payment_methods[enabled]" => true
    }

    request(:post, "/v1/payment_intents", body)
  end

  defp request(method, path, body) do
    case secret_key() do
      nil -> {:error, :missing_stripe_key}
      key ->
        req =
          Req.new(
            base_url: @base_url,
            headers: [{"authorization", "Bearer #{key}"}]
          )

        case Req.request(req, method: method, url: path, form: body) do
          {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
          {:ok, %{status: status, body: body}} -> {:error, {status, body}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp secret_key do
    System.get_env("STRIPE_SECRET_KEY")
  end
end
