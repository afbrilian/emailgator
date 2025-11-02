defmodule Emailgator.ApplicationTest do
  use ExUnit.Case, async: false

  alias Emailgator.Application

  describe "config_change/3" do
    test "handles config changes" do
      # This is a callback that just delegates to Endpoint
      result = Application.config_change([], [], [])
      assert result == :ok
    end
  end
end
