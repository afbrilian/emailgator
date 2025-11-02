defmodule Emailgator.AccountsFullTest do
  use Emailgator.DataCase

  alias Emailgator.Accounts

  describe "get_account_with_valid_token/1" do
    test "returns nil when account not found" do
      fake_id = Ecto.UUID.generate()
      assert Accounts.get_account_with_valid_token(fake_id) == nil
    end

    test "returns account when token not expired" do
      user = create_user()
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)
      account = create_account(user, %{expires_at: expires_at})

      # This will check token and return {:ok, account} if valid
      result = Accounts.get_account_with_valid_token(account.id)

      # Should return {:ok, account} since token is not expired
      assert {:ok, returned_account} = result
      assert returned_account.id == account.id
    end
  end

  describe "list_active_accounts/0" do
    test "returns only accounts with refresh_token" do
      user = create_user()
      active1 = create_account(user, %{refresh_token: "token1"})
      active2 = create_account(user, %{refresh_token: "token2"})

      accounts = Accounts.list_active_accounts()
      assert length(accounts) >= 2
      assert active1.id in Enum.map(accounts, & &1.id)
      assert active2.id in Enum.map(accounts, & &1.id)
    end
  end

  describe "get_account_by_email/2" do
    test "returns account when found" do
      user = create_user()
      account = create_account(user, %{email: "unique@example.com"})

      found = Accounts.get_account_by_email(user.id, "unique@example.com")
      assert found.id == account.id
    end

    test "returns nil when not found" do
      user = create_user()
      assert Accounts.get_account_by_email(user.id, "nonexistent@example.com") == nil
    end
  end
end
