defmodule ZcashExplorer.Metrics.NetworkSolpsWarmer do
  use Cachex.Warmer
  def interval, do: :timer.seconds(30)
  def execute(_state), do: ZcashExplorer.Snapshot.result("networksolps", ZcashExplorer.NetworkRate.sample())
end
