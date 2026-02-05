defmodule Bidph.Repo do
  use Ecto.Repo,
    otp_app: :bidph,
    adapter: Ecto.Adapters.Postgres
end
