defmodule Emailgator.Unsubscribe do
  @moduledoc """
  Context for managing unsubscribe attempts.
  """
  import Ecto.Query
  alias Emailgator.Repo
  alias Emailgator.Unsubscribe.UnsubscribeAttempt

  def create_attempt(attrs \\ %{}) do
    %UnsubscribeAttempt{}
    |> UnsubscribeAttempt.changeset(attrs)
    |> Repo.insert()
  end

  def list_email_attempts(email_id) do
    from(u in UnsubscribeAttempt, where: u.email_id == ^email_id, order_by: [desc: u.inserted_at])
    |> Repo.all()
  end
end
