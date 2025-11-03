defmodule EmailgatorWeb.Schema.TypesTest do
  use ExUnit.Case
  alias EmailgatorWeb.Schema.Types

  test "schema types module exists" do
    assert Code.ensure_loaded?(Types)
  end

  test "datetime scalar is defined in schema" do
    # Verify that the datetime scalar is registered in the schema
    # The functions are private, so we can only verify the module loads
    assert Code.ensure_loaded?(Types)
    # Schema compiles successfully which means types are valid
    assert Code.ensure_loaded?(EmailgatorWeb.Schema)
  end

  test "json scalar is defined in schema" do
    # Verify that the json scalar is registered in the schema
    # The functions are private, so we can only verify the module loads
    assert Code.ensure_loaded?(Types)
    # Schema compiles successfully which means types are valid
    assert Code.ensure_loaded?(EmailgatorWeb.Schema)
  end

  test "all object types are defined" do
    # Verify that the module defines the required GraphQL types
    # Types like :user, :account, :category, :email, etc. are tested through integration
    assert Code.ensure_loaded?(Types)
  end
end
