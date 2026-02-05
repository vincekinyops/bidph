defmodule Bidph.Repo.Migrations.CreateWalletsAndPayments do
  use Ecto.Migration

  def change do
    create table(:wallets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :balance, :decimal, null: false, default: 0
      add :held_balance, :decimal, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wallets, [:user_id])

    create table(:wallet_transactions) do
      add :wallet_id, references(:wallets, on_delete: :delete_all), null: false
      add :amount, :decimal, null: false
      add :transaction_type, :string, null: false
      add :provider, :string
      add :reference, :string
      add :status, :string, null: false, default: "posted"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:wallet_transactions, [:wallet_id])

    create table(:payment_methods) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :method_type, :string, null: false
      add :last4, :string
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:payment_methods, [:user_id])

    create table(:payment_holds) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :payment_method_id, references(:payment_methods, on_delete: :delete_all), null: false
      add :bid_id, references(:bids, on_delete: :delete_all), null: false
      add :amount, :decimal, null: false
      add :status, :string, null: false, default: "held"

      timestamps(type: :utc_datetime)
    end

    create index(:payment_holds, [:user_id])
    create index(:payment_holds, [:bid_id])
  end
end
