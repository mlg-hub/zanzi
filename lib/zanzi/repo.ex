defmodule Zanzi.Repo do
  use Ecto.Repo,
    otp_app: :zanzi,
    adapter: Ecto.Adapters.Postgres
end
