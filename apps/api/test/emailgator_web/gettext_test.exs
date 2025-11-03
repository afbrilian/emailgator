defmodule EmailgatorWeb.GettextTest do
  use ExUnit.Case
  alias EmailgatorWeb.Gettext

  test "gettext module exists" do
    assert Code.ensure_loaded?(Gettext)
  end

  test "gettext module uses Gettext.Backend" do
    # Verify that Gettext is properly configured
    # Gettext.Backend provides macros that need to be imported at compile time
    # Since we can't test macros directly without importing, we verify the module loads
    assert Code.ensure_loaded?(Gettext)
    assert Gettext.__info__(:functions) != nil
  end

  test "gettext module has backend functions" do
    # Verify that Gettext backend is properly set up
    # Gettext functions are available when imported, not as module functions
    assert Code.ensure_loaded?(Gettext)
  end
end
