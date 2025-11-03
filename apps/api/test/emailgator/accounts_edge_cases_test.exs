defmodule Emailgator.AccountsEdgeCasesTest do
  use Emailgator.DataCase

  alias Emailgator.Accounts

  setup do
    System.put_env("GOOGLE_CLIENT_ID", "test_client_id")
    System.put_env("GOOGLE_CLIENT_SECRET", "test_client_secret")

    :ok
  end

  describe "edge cases" do
    test "create_or_update_user with string keys" do
      attrs = %{"email" => "string1@example.com", "name" => "String User"}

      assert {:ok, user} = Accounts.create_or_update_user(attrs)
      assert user.email == "string1@example.com"

      # Update with same email
      attrs2 = %{"email" => "string1@example.com", "name" => "Updated Name"}
      assert {:ok, updated_user} = Accounts.create_or_update_user(attrs2)
      assert updated_user.id == user.id
      assert updated_user.name == "Updated Name"
    end

    test "update_user with empty name" do
      user = create_user(%{name: "Original Name"})

      attrs = %{name: ""}
      assert {:ok, updated} = Accounts.update_user(user, attrs)
      # Empty string may be stored as nil in database
      assert updated.name in [nil, ""]
    end

    test "update_user with nil name" do
      user = create_user(%{name: "Original Name"})

      attrs = %{name: nil}
      assert {:ok, updated} = Accounts.update_user(user, attrs)
      assert updated.name == nil
    end

    test "create_account with last_history_id" do
      user = create_user()
      history_id = "test_history_123"

      attrs = %{
        user_id: user.id,
        email: "test@example.com",
        access_token: "token",
        refresh_token: "refresh",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        last_history_id: history_id
      }

      assert {:ok, account} = Accounts.create_account(attrs)
      assert account.last_history_id == history_id
    end

    test "update_account with last_history_id" do
      user = create_user()
      account = create_account(user)
      new_history_id = "new_history_456"

      attrs = %{last_history_id: new_history_id}
      assert {:ok, updated} = Accounts.update_account(account, attrs)
      assert updated.last_history_id == new_history_id
    end

    test "update_account preserves other fields" do
      user = create_user()
      account = create_account(user, %{email: "original@example.com"})

      attrs = %{last_history_id: "history123"}
      assert {:ok, updated} = Accounts.update_account(account, attrs)
      assert updated.last_history_id == "history123"
      assert updated.email == "original@example.com"
    end

    test "get_account_by_email finds account" do
      user = create_user()
      account = create_account(user, %{email: "Test@Example.com"})

      # get_account_by_email matches by user_id and email
      result = Accounts.get_account_by_email(user.id, "Test@Example.com")
      assert result.id == account.id

      # Different user should not find it
      user2 = create_user()
      result2 = Accounts.get_account_by_email(user2.id, "Test@Example.com")
      assert result2 == nil
    end

    test "list_user_accounts with multiple users" do
      user1 = create_user()
      user2 = create_user()

      account1 = create_account(user1)
      account2 = create_account(user1)
      _account3 = create_account(user2)

      accounts = Accounts.list_user_accounts(user1.id)
      account_ids = Enum.map(accounts, & &1.id)

      assert account1.id in account_ids
      assert account2.id in account_ids
      assert length(accounts) == 2
    end

    test "delete_account removes account completely" do
      user = create_user()
      account = create_account(user)
      account_id = account.id

      assert {:ok, _deleted} = Accounts.delete_account(account)
      assert Accounts.get_account(account_id) == nil
    end

    test "get_account_with_valid_token with nil account returns nil" do
      fake_id = Ecto.UUID.generate()
      result = Accounts.get_account_with_valid_token(fake_id)
      assert result == nil
    end

    test "get_account_with_valid_token with valid token returns account" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      result = Accounts.get_account_with_valid_token(account.id)
      assert {:ok, returned_account} = result
      assert returned_account.id == account.id
    end
  end
end
