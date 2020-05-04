defmodule Zanzi.Repo.Migrations.AddordertypeonOrderPayment do
  use Ecto.Migration

  def change do
    alter table(:order_payments) do
      add :order_type, :string, default: "sales"
    end
  end
end
