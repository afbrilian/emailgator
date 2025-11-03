defmodule Emailgator.AccountsTest do
  use Emailgator.DataCase

  alias Emailgator.Accounts

  describe "users" do
    test "create_user/1 creates a user with valid attributes" do
      attrs = %{email: "test@example.com", name: "Test User"}
      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.name == "Test User"
    end

    test "create_user/1 validates email format" do
      attrs = %{email: "invalid-email", name: "Test User"}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end

    test "create_user/1 requires email" do
      attrs = %{name: "Test User"}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "get_user_by_email/1 returns user when exists" do
      user = create_user(%{email: "unique@example.com"})
      assert Accounts.get_user_by_email("unique@example.com").id == user.id
    end

    test "get_user_by_email/1 returns nil when user doesn't exist" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end

    test "create_or_update_user/1 creates new user" do
      attrs = %{"email" => "new@example.com", "name" => "New User"}
      assert {:ok, user} = Accounts.create_or_update_user(attrs)
      assert user.email == "new@example.com"
    end

    test "create_or_update_user/1 updates existing user" do
      user = create_user(%{email: "existing@example.com", name: "Old Name"})
      attrs = %{"email" => "existing@example.com", "name" => "New Name"}
      assert {:ok, updated_user} = Accounts.create_or_update_user(attrs)
      assert updated_user.id == user.id
      assert updated_user.name == "New Name"
    end
  end

  describe "accounts" do
    test "create_account/1 creates account with valid attributes" do
      user = create_user()

      attrs = %{
        email: "gmail@example.com",
        refresh_token: "refresh_123",
        access_token: "access_token_123",
        user_id: user.id
      }

      assert {:ok, account} = Accounts.create_account(attrs)
      assert account.email == "gmail@example.com"
      assert account.user_id == user.id
    end

    test "list_user_accounts/1 returns accounts for user" do
      user1 = create_user(%{email: "user1@example.com"})
      user2 = create_user(%{email: "user2@example.com"})

      account1 = create_account(user1, %{email: "account1@example.com"})
      account2 = create_account(user1, %{email: "account2@example.com"})
      _account3 = create_account(user2, %{email: "account3@example.com"})

      accounts = Accounts.list_user_accounts(user1.id)
      assert length(accounts) == 2
      assert account1.id in Enum.map(accounts, & &1.id)
      assert account2.id in Enum.map(accounts, & &1.id)
    end

    test "get_account/1 returns account when exists" do
      user = create_user()
      account = create_account(user)
      assert Accounts.get_account(account.id).id == account.id
    end

    test "delete_account/1 deletes account" do
      user = create_user()
      account = create_account(user)
      assert {:ok, _} = Accounts.delete_account(account)
      assert Accounts.get_account(account.id) == nil
    end
  end
end
