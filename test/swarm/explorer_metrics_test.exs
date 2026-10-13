defmodule ZcashExplorer.ExplorerMetricsTest do
  use ExUnit.Case, async: true
  alias ZcashExplorer.{Snapshot, NetworkRate}
  alias ZcashExplorer.Mempool.MempoolWarmer
  alias ZcashExplorerWeb.Number

  test "small positive difficulty survives formatting; unavailable is not zero" do
    assert Number.positive(0.0000000021) == "2.1000e-09"
    assert Number.positive(2.14363) == "2.14363"
    for value <- [nil, 0, -1, "bad"], do: assert(Number.positive(value) == "—")
    assert Number.decimal(79181.25) == "79,181.25"
  end

  test "mempool distinguishes an empty successful response from a failed response" do
    assert {:ok, []} = MempoolWarmer.normalize({:ok, %{}})
    assert {:ok, []} = MempoolWarmer.normalize({:ok, []})
    assert {:error, _} = MempoolWarmer.normalize({:error, :timeout})
    assert {:error, _} = MempoolWarmer.normalize({:ok, nil})
    assert {:error, _} = MempoolWarmer.normalize({:ok, %{"tx" => nil}})
    assert {:error, _} = MempoolWarmer.normalize({:ok, [12]})
    assert {:ok, [%{"txid" => "tx", "info" => %{}}]} = MempoolWarmer.normalize({:ok, ["tx"]})
    assert {:ok, [%{"info" => %{"fee" => 0}}]} = MempoolWarmer.normalize({:ok, %{"tx" => %{"fee" => 0}}})
  end

  test "peer responses accept genuine empty lists and reject malformed entries" do
    assert {:ok, []} = ZcashExplorer.Nodes.NodeWarmer.normalize({:ok, []})
    assert {:ok, [%{}]} = ZcashExplorer.Nodes.NodeWarmer.normalize({:ok, [%{}]})
    for result <- [{:ok, nil}, {:ok, %{}}, {:ok, [1]}, {:error, :timeout}], do: assert(match?({:error, _}, ZcashExplorer.Nodes.NodeWarmer.normalize(result)))
  end

  test "freshness has an explicit age limit and rejects future/missing timestamps" do
    assert Snapshot.fresh?(100, 120, 20)
    refute Snapshot.fresh?(100, 121, 20)
    refute Snapshot.fresh?(121, 120, 20)
    refute Snapshot.fresh?(nil, 120, 20)
    assert {:ok, [{"metric", 0}, {"metric:observed", time}]} = Snapshot.result("metric", {:ok, 0})
    assert is_integer(time)
    assert {:ok, [{"metric", nil}, {"metric:observed", nil}]} = Snapshot.result("metric", {:error, :timeout})
  end

  test "fractional network work rate is preserved rather than truncated" do
    first = %{"height" => 1, "timestamp" => 100, "hash" => "a", "bits" => "207fffff"}
    last = %{"height" => 2, "timestamp" => 200, "hash" => "b", "previousblockhash" => "a", "bits" => "207fffff"}
    assert NetworkRate.work("207fffff") == 2
    assert {:ok, 0.02} = NetworkRate.calculate([first, last])
    for bad <- [Map.put(last, "timestamp", 100), Map.put(last, "height", 1), Map.put(last, "previousblockhash", "reorg"), Map.put(last, "bits", "oops"), %{}] do
      assert {:error, _} = NetworkRate.calculate([first, bad])
    end
    for bad <- ["20800000", "20000000", "ff7fffff", "junk", nil], do: assert(is_nil(NetworkRate.work(bad)))
  end
end
