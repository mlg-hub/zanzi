defmodule Zanzi.Repo.Migrations.Addnewdepartement do
  use Ecto.Migration

  def change do
    alter table(:departements) do
      add :active_status, :integer, default: 0
    end

    alter table(:orders) do
      add :order_type, :string, default: "sales"
      add :payment_method, :integer, default: 0
    end
  end
end
