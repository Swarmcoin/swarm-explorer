defmodule ZcashExplorer.Mempool.MempoolWarmer do
  alias ZcashExplorer.{Rpc, Snapshot}
  use Cachex.Warmer
  def interval, do: :timer.seconds(5)
  def execute(_state), do: Snapshot.result("raw_mempool", normalize(Rpc.getrawmempool(true)))

  def normalize({:ok, rows}) when is_map(rows) do
    if Enum.all?(rows, fn {id, info} -> is_binary(id) and is_map(info) end) do
      {:ok, Enum.map(rows, fn {id, info} -> %{"txid" => id, "info" => info} end) |> Enum.sort_by(& &1["txid"])}
    else
      {:error, :invalid_mempool}
    end
  end
  def normalize({:ok, rows}) when is_list(rows) do
    if Enum.all?(rows, &is_binary/1), do: {:ok, Enum.map(rows, &%{"txid" => &1, "info" => %{}})}, else: {:error, :invalid_mempool}
  end
  def normalize(_), do: {:error, :unavailable}
end
