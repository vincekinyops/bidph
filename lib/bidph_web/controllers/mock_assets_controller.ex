defmodule BidphWeb.MockAssetsController do
  use BidphWeb, :controller

  @allowed ~r/^(featured-watch|auction-(art|car|jewelry|furniture)).*\.jpg$/i

  def show(conn, %{"file" => file}) do
    if Regex.match?(@allowed, file) do
      base_dir = Path.expand("../../assets/mock", __DIR__)
      path = Path.expand(file, base_dir)

      if String.starts_with?(path, base_dir) and File.exists?(path) do
        conn
        |> put_resp_content_type("image/jpeg")
        |> send_file(200, path)
      else
        send_resp(conn, 404, "not found")
      end
    else
      send_resp(conn, 404, "not found")
    end
  end
end
