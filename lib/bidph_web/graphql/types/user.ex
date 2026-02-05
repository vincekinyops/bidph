defmodule BidphWeb.GraphQL.Types.User do
  use Absinthe.Schema.Notation

  object :user do
    field :id, :id
    field :email, :string
    field :display_name, :string
    field :avatar_url, :string
    field :bio, :string
    field :inserted_at, :datetime
  end
end
