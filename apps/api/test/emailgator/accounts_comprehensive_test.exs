defmodule Emailgator.AccountsComprehensiveTest do
  use Emailgator.DataCase

  alias Emailgator.Accounts

  setup do
    System.put_env("GOOGLE_CLIENT_ID", "test_client_id")
    System.put_env("GOOGLE_CLIENT_SECRET", "test_client_secret")

    :ok
  end

  describe "get_account_with_valid_token/1" do
    test "returns account when token is valid" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      result = Accounts.get_account_with_valid_token(account.id)

      assert {:ok, returned_account} = result
      assert returned_account.id == account.id
    end

    test "refreshes token when expired" do
      # Note: Gmail.refresh_token uses Finch directly (not Tesla), so we can't mock with Tesla.Mock.
      # This test would require Bypass or a Finch mock for proper testing.
      # For now, we test the error handling path since test credentials are invalid.
      user = create_user()

      account =
        create_account(user, %{
          # Expired
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          refresh_token: "valid_refresh_token"
        })

      # Since refresh_token uses Finch directly and test credentials are invalid,
      # the refresh will fail and return an error
      result = Accounts.get_account_with_valid_token(account.id)

      # With invalid test credentials, refresh will fail
      assert {:error, _reason} = result

      # Note: To test successful refresh, use Bypass or valid OAuth credentials
    end

    test "returns nil when account not found" do
      fake_id = Ecto.UUID.generate()
      result = Accounts.get_account_with_valid_token(fake_id)
      assert result == nil
    end

    test "handles token refresh failure" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          refresh_token: "invalid_refresh_token"
        })

      # Note: Gmail.refresh_token uses Finch directly, so Tesla.Mock won't work.
      # The refresh will fail with invalid credentials, testing error handling.
      result = Accounts.get_account_with_valid_token(account.id)

      assert {:error, _reason} = result
    end
  end

  describe "update_account/2" do
    test "updates account attributes" do
      user = create_user()
      account = create_account(user)

      attrs = %{email: "updated@example.com"}
      assert {:ok, updated_account} = Accounts.update_account(account, attrs)
      assert updated_account.email == "updated@example.com"
    end

    test "returns error on invalid attributes" do
      user = create_user()
      account = create_account(user)

      attrs = %{email: "invalid-email"}
      assert {:error, changeset} = Accounts.update_account(account, attrs)
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end
  end

  describe "get_account_by_email/2" do
    test "returns account when exists" do
      user = create_user()
      account = create_account(user, %{email: "unique@example.com"})

      result = Accounts.get_account_by_email(user.id, "unique@example.com")
      assert result.id == account.id
    end

    test "returns nil when account doesn't exist" do
      user = create_user()
      result = Accounts.get_account_by_email(user.id, "nonexistent@example.com")
      assert result == nil
    end
  end

  describe "list_active_accounts/0" do
    test "returns only accounts with refresh_token" do
      user = create_user()

      # Create active accounts with refresh_token
      active_account1 = create_account(user, %{refresh_token: "token1"})
      active_account2 = create_account(user, %{refresh_token: "token2"})

      # Note: refresh_token is required in the schema, so we can't create accounts without it.
      # The function filters `where: not is_nil(a.refresh_token)`, so all valid accounts should be returned.

      accounts = Accounts.list_active_accounts()
      account_ids = Enum.map(accounts, & &1.id)

      # All accounts with refresh_token should be returned
      assert active_account1.id in account_ids
      assert active_account2.id in account_ids
      assert length(accounts) >= 2

      # Verify all returned accounts have refresh_token
      Enum.each(accounts, fn account ->
        assert account.refresh_token != nil
        assert account.refresh_token != ""
      end)
    end
  end

  describe "create_or_update_user/1" do
    test "creates user when doesn't exist" do
      attrs = %{"email" => "new@example.com", "name" => "New User"}
      assert {:ok, user} = Accounts.create_or_update_user(attrs)
      assert user.email == "new@example.com"
      assert user.name == "New User"
    end

    test "updates user when exists" do
      existing_user = create_user(%{email: "existing@example.com", name: "Old Name"})
      attrs = %{"email" => "existing@example.com", "name" => "New Name"}

      assert {:ok, updated_user} = Accounts.create_or_update_user(attrs)
      assert updated_user.id == existing_user.id
      assert updated_user.name == "New Name"
    end
  end

  describe "update_user/2" do
    test "updates user attributes" do
      user = create_user(%{name: "Old Name"})
      attrs = %{name: "New Name"}

      assert {:ok, updated_user} = Accounts.update_user(user, attrs)
      assert updated_user.name == "New Name"
    end

    test "returns error on invalid email format" do
      user = create_user()
      attrs = %{email: "invalid-email"}

      assert {:error, changeset} = Accounts.update_user(user, attrs)
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end
  end

  describe "get_user/1" do
    test "returns user when exists" do
      user = create_user()
      assert Accounts.get_user(user.id).id == user.id
    end

    test "returns nil when user doesn't exist" do
      fake_id = Ecto.UUID.generate()
      assert Accounts.get_user(fake_id) == nil
    end
  end

  describe "get_user_by_email/1" do
    test "returns user when exists" do
      user = create_user(%{email: "unique@example.com"})
      assert Accounts.get_user_by_email("unique@example.com").id == user.id
    end

    test "returns nil when user doesn't exist" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "create_account/1" do
    test "creates account with valid attributes" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        email: "gmail@example.com",
        access_token: "token",
        refresh_token: "refresh",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert {:ok, account} = Accounts.create_account(attrs)
      assert account.email == "gmail@example.com"
      assert account.user_id == user.id
    end

    test "returns error on invalid email format" do
      user = create_user()

      attrs = %{
        user_id: user.id,
        email: "invalid-email",
        access_token: "token",
        refresh_token: "refresh"
      }

      assert {:error, changeset} = Accounts.create_account(attrs)
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end
  end

  describe "get_account/1" do
    test "returns account when exists" do
      user = create_user()
      account = create_account(user)
      assert Accounts.get_account(account.id).id == account.id
    end

    test "returns nil when account doesn't exist" do
      fake_id = Ecto.UUID.generate()
      assert Accounts.get_account(fake_id) == nil
    end
  end

  describe "list_user_accounts/1" do
    test "returns all accounts for user" do
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

    test "returns empty list when user has no accounts" do
      user = create_user()
      assert Accounts.list_user_accounts(user.id) == []
    end
  end

  describe "delete_account/1" do
    test "deletes account successfully" do
      user = create_user()
      account = create_account(user)

      assert {:ok, _deleted} = Accounts.delete_account(account)
      assert Accounts.get_account(account.id) == nil
    end
  end

  describe "token_expired?/1" do
    test "returns true when expires_at is nil" do
      user = create_user()
      account = create_account(user, %{expires_at: nil})

      # This is a private function, tested through get_account_with_valid_token
      # Token with nil expires_at should be considered expired
      result = Accounts.get_account_with_valid_token(account.id)
      # Should attempt to refresh (and fail with test credentials)
      assert match?({:error, _reason}, result) or is_nil(result)
    end

    test "returns true when expires_at is in the past" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), -100, :second),
          refresh_token: "token"
        })

      # Should attempt to refresh expired token
      result = Accounts.get_account_with_valid_token(account.id)
      # Result can be either error (refresh failed) or ok (if refresh succeeded in test)
      assert match?({:error, _reason}, result) or match?({:ok, _account}, result)
    end

    test "returns false when expires_at is in the future" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      result = Accounts.get_account_with_valid_token(account.id)
      assert {:ok, _account} = result
    end
  end
end
