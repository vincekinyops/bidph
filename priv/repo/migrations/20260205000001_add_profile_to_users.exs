defmodule Bidph.Repo.Migrations.AddProfileToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :display_name, :string
      add :avatar_url, :string
      add :bio, :text
    end
  end
end
