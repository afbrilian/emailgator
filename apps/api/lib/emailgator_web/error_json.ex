defmodule EmailgatorWeb.ErrorJSON do
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  def error(%{error: error}) do
    %{error: error}
  end

  def render(:"404", _assigns), do: %{error: "Not found"}
  def render("404.json", _assigns), do: %{error: "Not found"}

  def render(:"401", _assigns), do: %{error: "Unauthorized"}
  def render("401.json", _assigns), do: %{error: "Unauthorized"}

  # Generic 500 error handler with optional reason details (for logs)
  def render(:"500", assigns), do: render("500.json", assigns)
  def render("500.json", assigns) do
    # Don't leak internal details; return a generic message to clients
    _ = Map.get(assigns, :reason)
    %{error: "Internal server error"}
  end

  # Fallback for any other status codes
  def render(template, _assigns) when is_binary(template) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn
      {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
