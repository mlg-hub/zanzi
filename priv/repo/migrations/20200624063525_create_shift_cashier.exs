defmodule Zanzi.Repo.Migrations.CreateShiftCashier do
  use Ecto.Migration

  def change do
    create table(:cashier_shifts) do
      add :user_id, references(:users, type: :string, on_delete: :nothing)
      add :shift_start, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
      add :shift_end, :utc_datetime, default: fragment("CURRENT_TIMESTAMP")
      add :shift_status, :integer, default: 1
      timestamps()
    end

    alter table(:orders) do
      add :cashier_shifts_id, references(:cashier_shifts, on_delete: :nothing)
    end
  end
end
