defmodule BrowseyHttp.Util.ExecTest do
  use ExUnit.Case

  @tag timeout: 10
  test "supports timeout" do
    assert {:error, [exit_status: _]} = BrowseyHttp.Util.Exec.exec("sleep 60s", 1)
  end
end
