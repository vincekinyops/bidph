defmodule Bidph.Listings.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active paused ended sold cancelled)

  schema "listings" do
    field :title, :string
    field :description, :string
    field :starting_price, :decimal
    field :reserve_price, :decimal
    field :current_price, :decimal
    field :status, :string, default: "active"
    field :end_at, :utc_datetime
    field :category, :string
    field :image_urls, {:array, :string}, default: []

    belongs_to :user, Bidph.Accounts.User
    has_many :bids, Bidph.Listings.Bid, preload_order: [desc: :amount]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listing, attrs) do
    listing
    |> cast(attrs, [
      :title,
      :description,
      :starting_price,
      :reserve_price,
      :current_price,
      :status,
      :end_at,
      :category,
      :image_urls,
      :user_id
    ])
    |> validate_required([:title, :starting_price, :end_at, :user_id])
    |> validate_number(:starting_price, greater_than: 0)
    |> validate_number(:reserve_price, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_end_at()
    |> set_current_price()
    |> foreign_key_constraint(:user_id)
  end

  def status_changeset(listing, status) do
    listing
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
  end

  defp validate_end_at(changeset) do
    end_at = get_field(changeset, :end_at)

    if end_at do
      if DateTime.compare(end_at, DateTime.utc_now()) != :gt do
        add_error(changeset, :end_at, "must be in the future")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp set_current_price(changeset) do
    current = get_field(changeset, :current_price)
    starting = get_field(changeset, :starting_price)

    if current do
      changeset
    else
      put_change(changeset, :current_price, starting || get_field(changeset, :starting_price))
    end
  end
end
