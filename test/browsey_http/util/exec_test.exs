defmodule BrowseyHttp.Util.ExecTest do
  use ExUnit.Case, async: true

  @tag timeout: 5_000
  test "supports timeout" do
    assert {:error, [exit_status: _]} = BrowseyHttp.Util.Exec.exec("sleep 60s", 1_000)
  end
end
