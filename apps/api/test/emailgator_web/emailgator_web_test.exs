defmodule EmailgatorWebTest do
  use ExUnit.Case

  describe "EmailgatorWeb module" do
    test "module exists and can be used" do
      assert Code.ensure_loaded?(EmailgatorWeb)
    end

    # Note: The macros (controller, router, channel) are defined but
    # can only be tested through actual usage, not via function_exported?
    # They're tested implicitly when controllers, routers, and channels use them
  end
end
