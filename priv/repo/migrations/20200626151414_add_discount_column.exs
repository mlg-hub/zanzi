defmodule Zanzi.Repo.Migrations.AddDiscountColumn do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :staff_discount, :integer, default: 0
      add :order_category, :integer, default: 1
    end
  end
end
