defmodule Emailgator.Repo.Migrations.CreateUnsubscribeAttempts do
  use Ecto.Migration

  def change do
    create table(:unsubscribe_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :method, :string, null: false
      add :url, :text, null: false
      add :status, :string, null: false
      add :evidence, :jsonb
      add :email_id, references(:emails, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:unsubscribe_attempts, [:email_id])
    create index(:unsubscribe_attempts, [:status])
  end
end

