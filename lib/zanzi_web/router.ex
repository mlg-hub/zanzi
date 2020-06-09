defmodule ZanziWeb.Router do
  use ZanziWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ZanziWeb.Context
  end

  scope "/admin", ZanziWeb do
    pipe_through :browser

    get "/", AdminController, :index
    resources "/sessions", SessionController, only: [:new, :create, :delete]

    scope "/menu" do
      get "/all", MenuItemsController, :all
      post "/new_item", MenuItemsController, :new_item
    end

    scope "/orders" do
      get "/cleared", OrderController, :cleared
      get "/pending", OrderController, :pending
      get "/voided", OrderController, :voided
      get "/unpaid", OrderController, :unpaid
      get "/complementary", OrderController, :complementary
      get "/remain", OrderController, :remain
      get "/detail/:id", OrderController, :detail
      post "/filter_date", OrderController, :filter_date
    end

    scope "/departement" do
      get "/stats_bar", DepartementController, :stats_bar
      get "/stats_coffee", DepartementController, :stats_coffee
      get "/stats_kitchen", DepartementController, :stats_kitchen
      get "/stats_restaurant", DepartementController, :stats_restaurant
      get "/stats_mini_bar", DepartementController, :stats_mini_bar
      post "/filter_date", DepartementController, :filter_date
    end
  end

  scope "/" do
    pipe_through :api

    forward "/api", Absinthe.Plug, schema: ZanziWeb.Schema

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: ZanziWeb.Schema,
      # interface: :playground,
      socket: ZanziWeb.UserSocket
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZanziWeb do
  #   pipe_through :api
  # end
end
