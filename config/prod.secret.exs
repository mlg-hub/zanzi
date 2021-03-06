# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

# System.get_env("DATABASE_URL") ||
#   raise """
#   environment variable DATABASE_URL is missing.
#   For example: ecto://USER:PASS@HOST/DATABASE
#   """
# database_url =
secret_key_base = "xky7XHeGtlslwQCAjXl9NG30QCz5OXXHdnUQyx1z/EhltMnnQhDckvY8O7Cb/+jn"

# System.get_env("SECRET_KEY_BASE") ||
#   raise """
#   environment variable SECRET_KEY_BASE is missing.
#   You can generate one by calling: mix phx.gen.secret
#   """

config :zanzi, ZanziWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: secret_key_base

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :zanzi, ZanziWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
config :zanzi, Zanzi.Repo,
  username: "zanzidev",
  password: "zanzidev",
  database: "zanzi_prod",
  hostname: "localhost",
  # show_sensitive_data_on_connection_error: true,
  pool_size: 15
