defmodule BidphWeb.GraphQL.Queries do
  use Absinthe.Schema.Notation

  alias Bidph.Listings

  object :queries do
    field :me, :user do
      resolve(fn _parent, _args, %{context: %{current_user: user}} when not is_nil(user) ->
        {:ok, user}
      end)

      resolve(fn _parent, _args, _resolution ->
        {:error, "Not authenticated"}
      end)
    end

    field :listing, :listing do
      arg(:id, non_null(:id))

      resolve(fn _parent, %{id: id}, _resolution ->
        case Listings.get_listing(id) do
          nil -> {:error, "Listing not found"}
          listing -> {:ok, listing}
        end
      end)
    end

    field :listings, list_of(:listing) do
      arg(:status, :string, default_value: "active")
      arg(:limit, :integer, default_value: 50)

      resolve(fn _parent, args, _resolution ->
        listings = Listings.list_listings(status: args.status, limit: args.limit)
        {:ok, listings}
      end)
    end

    field :user, :user do
      arg(:id, non_null(:id))

      resolve(fn _parent, %{id: id}, _resolution ->
        case Bidph.Accounts.get_user(id) do
          nil -> {:error, "User not found"}
          user -> {:ok, user}
        end
      end)
    end
  end
end
