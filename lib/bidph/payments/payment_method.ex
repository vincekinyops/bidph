defmodule Bidph.Payments.PaymentMethod do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending active inactive failed)
  @types ~w(card gcash maya bank)

  schema "payment_methods" do
    field :provider, :string
    field :method_type, :string
    field :last4, :string
    field :status, :string, default: "pending"
    field :external_id, :string
    field :verified_at, :utc_datetime

    belongs_to :user, Bidph.Accounts.User
    has_many :payment_holds, Bidph.Payments.PaymentHold

    timestamps(type: :utc_datetime)
  end

  def changeset(method, attrs) do
    method
    |> cast(attrs, [:provider, :method_type, :last4, :status, :external_id, :verified_at, :user_id])
    |> validate_required([:provider, :method_type, :status, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:method_type, @types)
    |> foreign_key_constraint(:user_id)
  end
end
