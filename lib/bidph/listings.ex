defmodule Bidph.Listings do
  @moduledoc """
  Context for listings and bids.
  """

  import Ecto.Query, warn: false
  alias Bidph.Repo

  alias Bidph.Listings.{Listing, Bid}
  alias Bidph.Accounts.User

  @doc """
  Returns the list of listings.
  """
  def list_listings(opts \\ []) do
    status = Keyword.get(opts, :status, "active")
    limit = Keyword.get(opts, :limit, 50)

    Listing
    |> where([l], l.status == ^status)
    |> where([l], l.end_at > ^DateTime.utc_now())
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload([:user, :bids])
  end

  @doc """
  Gets a single listing by id.
  """
  def get_listing!(id), do: Repo.get!(Listing, id) |> Repo.preload([:user, bids: [:user]])

  @doc """
  Gets a single listing by id, returns nil if not found.
  """
  def get_listing(id) do
    case Repo.get(Listing, id) do
      nil -> nil
      listing -> Repo.preload(listing, [:user, bids: [:user]])
    end
  end

  @doc """
  Creates a listing.
  """
  def create_listing(%User{} = user, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("current_price", attrs["starting_price"] || attrs[:starting_price])

    %Listing{}
    |> Listing.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a listing.
  """
  def update_listing(%Listing{} = listing, attrs) do
    listing
    |> Listing.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Places a bid on a listing. Validates:
  - Listing is active
  - End time hasn't passed
  - Bid amount > current price
  - User is not the seller
  """
  def place_bid(%Listing{} = listing, %User{} = user, amount) do
    amount = Decimal.new(to_string(amount))

    cond do
      listing.user_id == user.id ->
        {:error, :cannot_bid_on_own_listing}

      listing.status != "active" ->
        {:error, :listing_not_active}

      DateTime.compare(listing.end_at, DateTime.utc_now()) != :gt ->
        {:error, :auction_ended}

      Decimal.compare(amount, listing.current_price) != :gt ->
        {:error, :bid_too_low}

      true ->
        Repo.transaction(fn ->
          # Mark previous winning bid as not winning
          from(b in Bid, where: b.listing_id == ^listing.id and b.is_winning == true)
          |> Repo.update_all(set: [is_winning: false])

          # Insert new bid
          bid_attrs = %{
            listing_id: listing.id,
            user_id: user.id,
            amount: amount,
            is_winning: true
          }

          {:ok, bid} =
            %Bid{}
            |> Bid.changeset(bid_attrs)
            |> Repo.insert()

          # Update listing current_price
          listing
          |> Ecto.Changeset.change(current_price: amount)
          |> Repo.update!()

          Repo.preload(bid, [:user])
        end)
    end
  end

  @doc """
  Returns the highest bid for a listing.
  """
  def get_highest_bid(%Listing{id: listing_id}) do
    Bid
    |> where([b], b.listing_id == ^listing_id and b.is_winning == true)
    |> Repo.one()
    |> case do
      nil -> nil
      bid -> Repo.preload(bid, :user)
    end
  end

  @doc """
  Returns list of bids for a listing, ordered by amount desc.
  """
  def list_bids_for_listing(%Listing{id: listing_id}) do
    Bid
    |> where([b], b.listing_id == ^listing_id)
    |> order_by([b], desc: b.amount)
    |> Repo.all()
    |> Repo.preload(:user)
  end
end
