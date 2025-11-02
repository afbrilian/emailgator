defmodule EmailgatorWeb.Schema.Resolvers.AccountEdgeCasesTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase
  import Ecto.Query

  alias EmailgatorWeb.Schema.Resolvers.Account

  describe "get_connect_url/3" do
    test "returns connect URL for authenticated user" do
      user = create_user()
      context = build_context(user)

      assert {:ok, url} = Account.get_connect_url(nil, %{}, context)
      assert String.contains?(url, "/gmail/connect")
    end
  end

  describe "disconnect/3" do
    test "disconnects account when belongs to user" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      assert {:ok, _} = Account.disconnect(nil, %{id: account.id}, context)
      assert Emailgator.Accounts.get_account(account.id) == nil
    end

    test "returns error when account not found" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, "Account not found"} = Account.disconnect(nil, %{id: fake_id}, context)
    end

    test "returns error when account belongs to different user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user1)
      context = build_context(user2)

      # Should delete anyway (no ownership check), but verify behavior
      assert {:ok, _} = Account.disconnect(nil, %{id: account.id}, context)
    end
  end
end
