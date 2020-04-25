defmodule Zanzi.Repo.Migrations.AddPrintStatus do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:print_status, :integer, default: 0)
    end
  end
end
