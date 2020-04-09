defmodule ZanziWeb.Schema.AccountTypes do
  use Absinthe.Schema.Notation

  object :session do
    field(:token, :string)
    field(:user, :user)
  end

  enum :rights do
    value(:ar)
    value(:psp)
    value(:pssmp)
    value(:spii)
    value(:cbcs)
    value(:psvb)
  end

  object :user do
    field(:username, :string)
    field(:full_name, :string)
    field(:id, :string)
    field(:position, list_of(:position))
  end

  object :position do
    field(:position_name, :string)
    field(:role, list_of(:user_role))
  end

  object :user_role do
    field(:id, :string)
    field(:name, :string)
  end
end
