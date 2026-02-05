defmodule BidphWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(BidphWeb.GraphQL.Types.User)
  import_types(BidphWeb.GraphQL.Types.Listing)
  import_types(BidphWeb.GraphQL.Types.Bid)
  import_types(BidphWeb.GraphQL.Queries)
  import_types(BidphWeb.GraphQL.Mutations)

  query do
    import_fields(:queries)
  end

  mutation do
    import_fields(:mutations)
  end
end
