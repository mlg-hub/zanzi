defmodule ZanziWeb.Presence do
  use Phoenix.Presence,
    otp_app: :zanzi,
    pubsub_server: Zanzi.PubSub
end
