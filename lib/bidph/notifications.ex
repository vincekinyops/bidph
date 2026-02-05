defmodule Bidph.Notifications do
  @moduledoc """
  Email notifications.
  """

  import Swoosh.Email
  alias Bidph.Mailer
  alias Bidph.Accounts.User
  alias Bidph.Payments.WalletTransaction

  def send_topup_receipt(%User{} = user, %WalletTransaction{} = tx) do
    new()
    |> to({user.display_name || user.email, user.email})
    |> from({"Bidph", mail_from()})
    |> subject("Wallet Top-up Receipt")
    |> text_body("""
    Thanks for topping up your wallet.

    Receipt: #{tx.receipt_number || "N/A"}
    Amount: ₱#{Decimal.to_string(tx.amount)}
    Provider: #{tx.provider || "N/A"}
    Status: #{tx.status}

    #{if tx.receipt_url, do: "Receipt URL: #{tx.receipt_url}", else: ""}
    """)
    |> Mailer.deliver()
  end

  def send_payment_method_verified(%User{} = user, provider) do
    new()
    |> to({user.display_name || user.email, user.email})
    |> from({"Bidph", mail_from()})
    |> subject("Payment Method Verified")
    |> text_body("""
    Your payment method has been verified.

    Provider: #{provider}
    """)
    |> Mailer.deliver()
  end

  defp mail_from do
    System.get_env("MAIL_FROM") || "no-reply@bidph.local"
  end
end
