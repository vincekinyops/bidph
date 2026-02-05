defmodule BidphWeb.GraphQL.Types.Listing do
  use Absinthe.Schema.Notation

  object :listing do
    field :id, :id
    field :title, :string
    field :description, :string
    field :starting_price, :decimal
    field :reserve_price, :decimal
    field :current_price, :decimal
    field :status, :string
    field :end_at, :datetime
    field :category, :string
    field :image_urls, list_of(:string)
    field :inserted_at, :datetime

    field :seller, :user do
      resolve(fn listing, _, _ ->
        {:ok, Bidph.Repo.preload(listing, :user).user}
      end)
    end

    field :bids, list_of(:bid) do
      resolve(fn listing, _, _ ->
        {:ok, Bidph.Repo.preload(listing, bids: :user).bids}
      end)
    end

    field :highest_bid, :bid do
      resolve(fn listing, _, _ ->
        highest = Bidph.Listings.get_highest_bid(listing)
        {:ok, highest}
      end)
    end
  end
end
