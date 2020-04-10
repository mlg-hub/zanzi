defmodule Zanzi.Repo.Migrations.CreateRequiredTables do
  use Ecto.Migration

  def change do
    create table(:departements) do
      add :name, :string, null: false
      timestamps()
    end

    create table(:categories) do
      add :name, :string, null: false
      add :departement_id, references(:departements)
      timestamps()
    end

    create unique_index(:categories, [:name])

    create table(:items) do
      add(:name, :string, null: false)
      add(:price, :integer, null: false)
      add(:added_on, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP"))
      add(:departement_id, references(:departements, on_delete: :nothing))
      add(:category_id, references(:categories, on_delete: :nothing))
      timestamps()
    end

    create(index(:items, [:departement_id, :category_id]))

    create table(:tables) do
      add :number, :integer
      timestamps()
    end

    create table(:positions) do
      add :position_name, :string
    end

    create table(:roles) do
      add :name, :string
      timestamps()
    end

    create table(:positions_roles) do
      add :position_id, references(:positions)
      add :role_id, references(:roles)
    end

    create table(:users, primary_key: false) do
      add(:id, :string, primary_key: true, size: 27)
      add(:full_name, :string, null: false)
      add(:username, :string)
      add(:password, :string, null: false)
      add(:plain_pwd, :string, null: false)
    end

    create(index(:users, [:id]))

    create table(:users_positions) do
      add :user_id, references(:users, type: :string)
      add(:position_id, references(:positions))
      # timestamps()
    end

    create table(:orders) do
      add(:code, :string, null: false)
      add(:ordered_at, :utc_datetime, null: false, default: fragment("NOW()"))
      add :table_id, references(:tables)
      add :total, :integer, default: 0
      add :merged_status, :integer, default: 0
      add :split_status, :integer, default: 0
      add(:filled, :integer, default: 1)
      add(:splitted_from, :id)
      add(:status, :string, null: false, default: "created")
      timestamps()
    end

    create table(:order_details) do
      add(:order_id, references(:orders))
      add(:departement_id, references(:departements))
      add(:item_id, references(:items))
      add(:sold_price, :decimal, null: false)
      add(:sold_quantity, :integer, null: false)
      add(:comments, :text)
      add(:current_order, references(:orders))
      add(:former_order, references(:orders))
      add(:split_status, :integer, default: 0)
      timestamps()
    end

    create(index(:order_details, [:order_id, :departement_id, :item_id]))

    create table(:order_splits) do
      add(:order_id, references(:orders))
      add(:split_by, references(:users, type: :string))
      add(:split_code, :string)
      add(:split_total, :integer)
      timestamps()
    end

    create table(:order_splits_details) do
      add(:order_splits_id, references(:order_splits))
      add(:item_id, references(:items))
      add(:departement_id, references(:departements))
      add(:sold_price, :integer, null: false)
      add(:sold_quantity, :integer, null: false)
      timestamps()
    end

    create table(:order_merges) do
      add(:main_order_id, references(:orders))
      # add :order_merges_id, references(:orders)
      add(:sub_order_id, references(:orders))
      add(:user_id, references(:users, type: :string))
      timestamps()
    end

    create table(:order_payments) do
      add(:order_id, references(:orders))
      add(:order_total, :integer, null: false)
      add(:order_paid, :integer, null: false)
      add(:user_id, references(:users, type: :string), on_delete: :nothing)
      timestamps()
    end

    create table(:orders_owners) do
      add(:order_id, references(:orders))
      add(:current_owner, references(:users, type: :string))
      add(:from_owner, references(:users, type: :string))
      # committed accepted requested rejected
      add(:status, :string, default: "committed")
      add(:transfer_to, references(:users, type: :string))
      timestamps()
    end
  end
end
