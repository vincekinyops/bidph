defmodule Bidph.Payments.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "wallets" do
    field :balance, :decimal, default: 0
    field :held_balance, :decimal, default: 0

    belongs_to :user, Bidph.Accounts.User
    has_many :transactions, Bidph.Payments.WalletTransaction

    timestamps(type: :utc_datetime)
  end

  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:balance, :held_balance, :user_id])
    |> validate_required([:balance, :held_balance, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
