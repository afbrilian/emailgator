defmodule Emailgator.Repo.Migrations.CreateEmails do
  use Ecto.Migration

  def change do
    create table(:emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :gmail_message_id, :string, null: false
      add :subject, :string
      add :from, :string
      add :snippet, :text
      add :summary, :text
      add :body_text, :text
      add :body_html, :text
      add :unsubscribe_urls, {:array, :string}, default: []
      add :archived_at, :utc_datetime
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :category_id, references(:categories, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:emails, [:account_id, :gmail_message_id])
    create index(:emails, [:account_id])
    create index(:emails, [:category_id])
  end
end

