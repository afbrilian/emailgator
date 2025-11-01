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

  def render(:"404", _assigns) do
    %{error: "Not found"}
  end

  def render(:"401", _assigns) do
    %{error: "Unauthorized"}
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
