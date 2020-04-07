defmodule Zanzi.Repo.Migrations.TestTable do
  use Ecto.Migration

  def change do
    create table(:test_zanzi) do
      add :name, :string
    end
  end
end
