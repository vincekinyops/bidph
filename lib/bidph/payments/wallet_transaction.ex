defmodule Bidph.Payments.WalletTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(top_up hold release capture refund adjustment)
  @statuses ~w(pending posted failed)

  schema "wallet_transactions" do
    field :amount, :decimal
    field :transaction_type, :string
    field :provider, :string
    field :reference, :string
    field :status, :string, default: "posted"
    field :external_id, :string
    field :receipt_number, :string
    field :receipt_url, :string

    belongs_to :wallet, Bidph.Payments.Wallet

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:amount, :transaction_type, :provider, :reference, :status, :external_id, :receipt_number, :receipt_url, :wallet_id])
    |> validate_required([:amount, :transaction_type, :status, :wallet_id])
    |> validate_inclusion(:transaction_type, @types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:wallet_id)
  end
end
