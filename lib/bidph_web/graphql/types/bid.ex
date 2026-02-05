defmodule BidphWeb.GraphQL.Types.Bid do
  use Absinthe.Schema.Notation

  object :bid do
    field :id, :id
    field :amount, :decimal
    field :is_winning, :boolean
    field :inserted_at, :datetime

    field :user, :user do
      resolve(fn bid, _, _ ->
        {:ok, Bidph.Repo.preload(bid, :user).user}
      end)
    end

    field :listing, :listing do
      resolve(fn bid, _, _ ->
        {:ok, Bidph.Repo.preload(bid, :listing).listing}
      end)
    end
  end
end
