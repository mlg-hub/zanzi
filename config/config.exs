# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :zanzi,
  ecto_repos: [Zanzi.Repo]

# Configures the endpoint
config :zanzi, ZanziWeb.Endpoint,
  url: [host: "192.168.1.15"],
  secret_key_base: "AuPIofgqslTdn/ZRXQ6WAWFh3sMlixriPEyZ+X3CTNcYYYPt5dt8IUs3GF65jdNr",
  render_errors: [view: ZanziWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Zanzi.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
