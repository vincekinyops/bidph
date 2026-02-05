defmodule Bidph.Repo.Migrations.CreateListings do
  use Ecto.Migration

  def change do
    create table(:listings) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :title, :string, null: false
      add :description, :text
      add :starting_price, :decimal, precision: 12, scale: 2, null: false
      add :reserve_price, :decimal, precision: 12, scale: 2
      add :current_price, :decimal, precision: 12, scale: 2, null: false
      add :status, :string, null: false, default: "active"
      add :end_at, :utc_datetime, null: false
      add :category, :string
      add :image_urls, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:listings, [:user_id])
    create index(:listings, [:status])
    create index(:listings, [:end_at])
    create index(:listings, [:category])
    create index(:listings, [:status, :end_at])
  end
end
