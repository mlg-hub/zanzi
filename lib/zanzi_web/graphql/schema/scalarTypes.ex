defmodule ZanziWeb.Schema.ScalarTypes do
  use Absinthe.Schema.Notation

  scalar :decimal do
    parse(fn
      %{value: value}, _ -> Decimal.parse(value)
      _, _ -> :error
    end)

    serialize(&to_string/1)
  end

  scalar :date do
    parse(
      fn input ->
        # Parsing logic here
        with %Absinthe.Blueprint.Input.String{value: value} <- input,
             {:ok, date} <- Date.from_iso8601(value) do
          {:ok, date}
        else
          _ -> :error
        end
      end

      # case(Date.from_iso8601(input.value)) do
      #   {:ok, date} -> {:ok, date}
      #   _ -> :error
      # end
    )

    serialize(fn date ->
      # Serialization logic here
      Date.to_iso8601(date)
    end)
  end
end
