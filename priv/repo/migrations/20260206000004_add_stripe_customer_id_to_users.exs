defmodule Bidph.Repo.Migrations.AddStripeCustomerIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_customer_id, :string
    end

    create index(:users, [:stripe_customer_id])
  end
end
