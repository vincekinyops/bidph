defmodule Bidph.Repo.Migrations.AddIsSuperAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_super_admin, :boolean, default: false, null: false
    end

    create index(:users, [:is_super_admin])
  end
end
