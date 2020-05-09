defmodule Zanzi.Repo.Migrations.OrderVoidReson do
  use Ecto.Migration

  def change do
    create table(:order_void_reasons) do
      add :order_id, references(:orders)
      add :void_reason, :string, null: false
      timestamps()
    end
  end
end
