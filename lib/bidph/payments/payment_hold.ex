defmodule Bidph.Payments.PaymentHold do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(held released captured failed)

  schema "payment_holds" do
    field :amount, :decimal
    field :status, :string, default: "held"

    belongs_to :user, Bidph.Accounts.User
    belongs_to :payment_method, Bidph.Payments.PaymentMethod
    belongs_to :bid, Bidph.Listings.Bid

    timestamps(type: :utc_datetime)
  end

  def changeset(hold, attrs) do
    hold
    |> cast(attrs, [:amount, :status, :user_id, :payment_method_id, :bid_id])
    |> validate_required([:amount, :status, :user_id, :payment_method_id, :bid_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:payment_method_id)
    |> foreign_key_constraint(:bid_id)
  end
end
