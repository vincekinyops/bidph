defmodule BidphWeb.PageController do
  use BidphWeb, :controller

  alias Bidph.Listings
  alias Bidph.Listings.{Listing, Bid}

  def home(conn, _params) do
    listings = Listings.list_listings(limit: 9)
    {featured_listing, hot_listings} =
      if listings == [] do
        {mock_featured_listing(), mock_hot_listings()}
      else
        {List.first(listings), listings |> Enum.drop(1) |> Enum.take(8)}
      end

    conn
    |> assign(:featured_listing, featured_listing)
    |> assign(:listings, hot_listings)
    |> assign(:stats, %{
      total_sales_volume: "₱24M+",
      active_auctions: "1,240",
      verified_collectors: "45K+"
    })
    |> render(:home)
  end

  defp mock_featured_listing do
    now = DateTime.utc_now()

    %Listing{
      id: 0,
      title: "1965 Vintage Chronograph",
      description: "Rare collector's piece with original documentation. Swiss made, excellent condition.",
      current_price: Decimal.new("45000"),
      end_at: DateTime.add(now, 3, :hour),
      category: "Watches",
      image_urls: ["/mock/featured-watch-Dja3J0Pt.jpg"],
      bids: [
        %Bid{amount: Decimal.new("45000"), inserted_at: DateTime.add(now, -2, :minute)},
        %Bid{amount: Decimal.new("44500"), inserted_at: DateTime.add(now, -5, :minute)},
        %Bid{amount: Decimal.new("44000"), inserted_at: DateTime.add(now, -8, :minute)}
      ]
    }
  end

  defp mock_hot_listings do
    now = DateTime.utc_now()

    [
      %Listing{
        id: -1,
        title: "Abstract Geometric Composition by Marc...",
        current_price: Decimal.new("12500"),
        end_at: DateTime.add(now, 1, :hour),
        category: "Art",
        image_urls: ["/mock/auction-art-DXFPezdl.jpg"],
        bids: []
      },
      %Listing{
        id: -2,
        title: "1962 Ferrari 250 GT California Spider",
        current_price: Decimal.new("875000"),
        end_at: DateTime.add(now, 5, :hour),
        category: "Cars",
        image_urls: ["/mock/auction-car-BKsFwp2x.jpg"],
        bids: []
      },
      %Listing{
        id: -3,
        title: "Victorian Diamond Necklace, c.1890",
        current_price: Decimal.new("34000"),
        end_at: DateTime.add(now, 12, :hour),
        category: "Jewelry",
        image_urls: ["/mock/auction-jewelry-CLPqj-_P.jpg"],
        bids: []
      },
      %Listing{
        id: -4,
        title: "Louis XV Carved Armchair, 18th Century",
        current_price: Decimal.new("8500"),
        end_at: DateTime.add(now, 24, :hour),
        category: "Furniture",
        image_urls: ["/mock/auction-furniture-CQ8ck3wV.jpg"],
        bids: []
      }
    ]
  end
end
