defmodule Bidph.Listings.Bid do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bids" do
    field :amount, :decimal
    field :is_winning, :boolean, default: false

    belongs_to :listing, Bidph.Listings.Listing
    belongs_to :user, Bidph.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(bid, attrs) do
    bid
    |> cast(attrs, [:amount, :is_winning, :listing_id, :user_id])
    |> validate_required([:amount, :listing_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:listing_id)
    |> foreign_key_constraint(:user_id)
  end
end
