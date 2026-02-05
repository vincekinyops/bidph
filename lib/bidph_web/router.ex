defmodule BidphWeb.Router do
  use BidphWeb, :router

  import BidphWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BidphWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/webhooks", BidphWeb.Webhooks do
    pipe_through :api

    post "/payments", PaymentController, :create
    post "/stripe", StripeController, :create
  end

  pipeline :graphql do
    plug :accepts, ["json", "html"]
    plug :fetch_session
    plug BidphWeb.Plugs.GraphQLContext
  end

  scope "/api" do
    pipe_through :graphql

    forward "/", Absinthe.Plug, schema: BidphWeb.GraphQL.Schema
  end

  scope "/" do
    pipe_through :graphql

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: BidphWeb.GraphQL.Schema,
      interface: :playground
  end

  scope "/", BidphWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/mock/:file", MockAssetsController, :show

    live_session :default, on_mount: [BidphWeb.UserAuthLive] do
      live "/listings", ListingsLive.Index, :index
      live "/listings/new", ListingsLive.Index, :new
      live "/listings/:id", ListingsLive.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BidphWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bidph, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BidphWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BidphWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", BidphWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", BidphWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :account, on_mount: [BidphWeb.UserAuthLive] do
      live "/wallet", WalletLive.TopUp, :index
      live "/payment-methods", PaymentMethodsLive.Index, :index
      live "/profile", ProfileLive.Show, :show
      live "/my-listings", MyListingsLive.Index, :index
    end
  end

  scope "/admin", BidphWeb do
    pipe_through [:browser, :require_authenticated_user, :require_super_admin]

    live_session :admin, on_mount: [BidphWeb.UserAuthLive] do
      live "/", AdminLive.Dashboard, :index
    end
  end

  scope "/", BidphWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
