defmodule Emailgator.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :access_token, :text, null: false
      add :refresh_token, :text, null: false
      add :expires_at, :utc_datetime
      add :last_history_id, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:user_id, :email])
    create index(:accounts, [:user_id])
  end
end

