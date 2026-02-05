defmodule Bidph.Repo.Migrations.CreateBids do
  use Ecto.Migration

  def change do
    create table(:bids) do
      add :listing_id, references(:listings, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :is_winning, :boolean, default: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:bids, [:listing_id])
    create index(:bids, [:user_id])
    create index(:bids, [:listing_id, :amount], name: :bids_listing_amount_desc_idx)
  end
end
