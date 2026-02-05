defmodule BidphWeb.GraphQL.Mutations do
  use Absinthe.Schema.Notation

  alias Bidph.Listings

  object :mutations do
    field :create_listing, :listing do
      arg(:title, non_null(:string))
      arg(:description, :string)
      arg(:starting_price, non_null(:decimal))
      arg(:reserve_price, :decimal)
      arg(:end_at, non_null(:string))
      arg(:category, :string)
      arg(:image_urls, list_of(:string))

      resolve(fn _parent, args, %{context: %{current_user: user}} when not is_nil(user) ->
        end_at = parse_datetime(args.end_at)

        attrs = %{
          "title" => args.title,
          "description" => args[:description],
          "starting_price" => args.starting_price,
          "reserve_price" => args[:reserve_price],
          "end_at" => end_at,
          "category" => args[:category],
          "image_urls" => args[:image_urls] || []
        }

        case Listings.create_listing(user, attrs) do
          {:ok, listing} -> {:ok, Listings.get_listing!(listing.id)}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end
      end)

      resolve(fn _parent, _args, _resolution ->
        {:error, "Not authenticated"}
      end)
    end

    field :place_bid, :bid do
      arg(:listing_id, non_null(:id))
      arg(:amount, non_null(:decimal))

      resolve(fn _parent, args, %{context: %{current_user: user}} when not is_nil(user) ->
        case Listings.get_listing(args.listing_id) do
          nil ->
            {:error, "Listing not found"}

          listing ->
            case Listings.place_bid(listing, user, args.amount) do
              {:ok, bid} -> {:ok, bid}
              {:error, :cannot_bid_on_own_listing} -> {:error, "Cannot bid on your own listing"}
              {:error, :listing_not_active} -> {:error, "Listing is not active"}
              {:error, :auction_ended} -> {:error, "Auction has ended"}
              {:error, :bid_too_low} -> {:error, "Bid must be higher than current price"}
            end
        end
      end)

      resolve(fn _parent, _args, _resolution ->
        {:error, "Not authenticated"}
      end)
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp format_changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    Enum.map(errors, fn {field, msgs} ->
      "#{field}: #{Enum.join(msgs, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
