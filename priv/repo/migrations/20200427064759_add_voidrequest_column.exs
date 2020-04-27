defmodule Zanzi.Repo.Migrations.AddVoidrequestColumn do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :void_request, :integer, default: 0
    end
  end
end
