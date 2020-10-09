defmodule Zanzi.Repo.Migrations.AddStatus do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :integer, default: 0
    end
  end
end
