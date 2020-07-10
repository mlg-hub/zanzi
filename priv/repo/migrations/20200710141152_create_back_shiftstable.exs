defmodule Zanzi.Repo.Migrations.CreateBackShiftstable do
  use Ecto.Migration

  def change do
  end

  #   def change do
  #     create table(:cashier_shifts) do
  #       add :user_id, references(:users, type: :string, on_delete: :nothing)
  #       add :shift_start, :utc_datetime, null: false
  #       add :shift_end, :utc_datetime
  #       add :shift_status, :integer, default: 1
  #       timestamps(type: :utc_datetime)
  #     end
  #   end

  def change do
    alter table(:orders) do
      add :staff_discount, :integer, default: 0
      add :order_category, :integer, default: 1
      add :cashier_shifts_id, references(:cashier_shifts, on_delete: :nothing)
    end
  end
end
