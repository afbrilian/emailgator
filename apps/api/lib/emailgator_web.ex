defmodule EmailgatorWeb do
  @moduledoc """
  The entrypoint for defining your web interface.

  This defines the helpers for controllers, views, router, etc.
  """
  def controller do
    quote do
      use Phoenix.Controller, namespace: EmailgatorWeb
      import Plug.Conn
      import EmailgatorWeb.Gettext
      action_fallback(EmailgatorWeb.FallbackController)
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import EmailgatorWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
