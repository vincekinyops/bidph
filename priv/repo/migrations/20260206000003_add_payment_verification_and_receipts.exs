defmodule Bidph.Repo.Migrations.AddPaymentVerificationAndReceipts do
  use Ecto.Migration

  def change do
    alter table(:payment_methods) do
      add :external_id, :string
      add :verified_at, :utc_datetime
    end

    alter table(:wallet_transactions) do
      add :external_id, :string
      add :receipt_number, :string
      add :receipt_url, :string
    end

    execute("UPDATE payment_methods SET status = 'pending' WHERE status IS NULL")
    execute("ALTER TABLE payment_methods ALTER COLUMN status SET DEFAULT 'pending'")
  end
end
