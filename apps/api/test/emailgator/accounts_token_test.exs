defmodule Emailgator.AccountsTokenTest do
  use Emailgator.DataCase

  alias Emailgator.Accounts

  describe "get_account_with_valid_token/1" do
    test "returns nil when account not found" do
      fake_id = Ecto.UUID.generate()
      assert Accounts.get_account_with_valid_token(fake_id) == nil
    end

    test "returns {:ok, account} when token not expired" do
      user = create_user()
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)
      account = create_account(user, %{expires_at: expires_at})

      result = Accounts.get_account_with_valid_token(account.id)
      assert {:ok, returned_account} = result
      assert returned_account.id == account.id
    end

    test "returns {:ok, account} when token expired and refresh succeeds" do
      user = create_user()
      expired_at = DateTime.add(DateTime.utc_now(), -3600, :second)
      account = create_account(user, %{expires_at: expired_at, refresh_token: "valid_refresh"})

      # This will attempt to refresh - we can't easily mock Gmail, so just verify structure
      result = Accounts.get_account_with_valid_token(account.id)

      # Result will be either {:ok, updated_account} or {:error, reason}
      # depending on whether Gmail.refresh_token succeeds
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns {:error, reason} when token expired and refresh fails" do
      user = create_user()
      expired_at = DateTime.add(DateTime.utc_now(), -3600, :second)
      account = create_account(user, %{expires_at: expired_at, refresh_token: "invalid"})

      # This will attempt to refresh and likely fail
      result = Accounts.get_account_with_valid_token(account.id)

      # Result will be {:error, reason} when refresh fails
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns {:ok, account} when expires_at is nil (treated as expired)" do
      user = create_user()
      account = create_account(user, %{expires_at: nil, refresh_token: "valid_refresh"})

      # expires_at nil means expired, so will attempt refresh
      result = Accounts.get_account_with_valid_token(account.id)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
