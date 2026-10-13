defmodule ZcashExplorer.Nodes.NodeWarmer do
  alias ZcashExplorer.Rpc
  use Cachex.Warmer
  require Logger

  @doc """
  Returns the interval for this warmer.
  """
  def interval,
    do: :timer.seconds(60)

  @doc """
  Executes this cache warmer.
  """
  def execute(_state) do
    Rpc.getpeerinfo() |> normalize() |> handle_result()
  end

  def normalize({:ok, nodes}) when is_list(nodes) do
    if Enum.all?(nodes, &is_map/1), do: {:ok, nodes}, else: {:error, :invalid_peers}
  end
  def normalize(_), do: {:error, :unavailable}

  # Clear errors rather than keeping an old count.
  defp handle_result({:error, reason}) do
    Logger.error("Error while warming the nodes cache: #{inspect(reason)}")
    ZcashExplorer.Snapshot.result("zcash_nodes", {:error, reason})
  end

  defp handle_result({:ok, nodes}) do
    ZcashExplorer.Snapshot.result("zcash_nodes", {:ok, nodes})
  end
end
