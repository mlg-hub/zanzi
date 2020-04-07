defmodule Zanzibloc.Ecto.Ksuid do
  @moduledoc false
  @behaviour Ecto.Type

  def type, do: :string
  def cast(ksuid) when is_binary(ksuid) and byte_size(ksuid) == 27, do: {:ok, ksuid}
  def cast(_), do: :error

  def load(ksuid), do: {:ok, ksuid}
  def dump(binary) when is_binary(binary), do: {:ok, binary}
  def dump(_), do: :error
  def autogenerate, do: Ksuid.generate()
end
