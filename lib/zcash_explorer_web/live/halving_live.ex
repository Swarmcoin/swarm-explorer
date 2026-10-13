defmodule ZcashExplorerWeb.HalvingLive do
  @moduledoc """
  The height of the next halving and how many blocks are left.

  The interval is configuration (`SWARM_HALVING_INTERVAL`, default 1,680,000),
  which puts the first halving at height 1,679,999 — `specs/ECONOMICS.md` §3.
  """
  use ZcashExplorerWeb, :live_view
  alias ZcashExplorerWeb.MetricCard

  @refresh 15_000

  @impl true
  def render(assigns), do: MetricCard.card(assigns)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, @refresh)
    {:ok, assign(socket, figures())}
  end

  @impl true
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @refresh)
    {:noreply, assign(socket, figures())}
  end

  defp figures do
    case ZcashExplorer.Snapshot.field("metrics", "blocks") do
      height when is_integer(height) ->
        [
          key: "NEXT HALVING",
          value: "#" <> ZcashExplorerWeb.Number.decimal(ZcashExplorer.Swarm.next_halving_height(height), 0),
          note: "#{ZcashExplorerWeb.Number.decimal(ZcashExplorer.Swarm.blocks_to_halving(height), 0)} blocks to go",
          accent: MetricCard.honey()
        ]

      _ ->
        [
          key: "NEXT HALVING",
          value: "—",
          note: "reward halves, the 80/8/4/8 split does not",
          accent: MetricCard.honey()
        ]
    end
  end
end
