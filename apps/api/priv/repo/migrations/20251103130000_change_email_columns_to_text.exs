defmodule Emailgator.Repo.Migrations.ChangeEmailColumnsToText do
  use Ecto.Migration

  def up do
    alter table(:emails) do
      modify :subject, :text
      modify :from, :text
      modify :gmail_message_id, :text
      modify :unsubscribe_urls, {:array, :text}, from: {:array, :string}
    end
  end

  def down do
    alter table(:emails) do
      modify :subject, :string
      modify :from, :string
      modify :gmail_message_id, :string
      modify :unsubscribe_urls, {:array, :string}, from: {:array, :text}
    end
  end
end

