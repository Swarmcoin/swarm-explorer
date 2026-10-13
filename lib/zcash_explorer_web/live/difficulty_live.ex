defmodule ZcashExplorerWeb.DifficultyLive do
  @moduledoc """
  Current difficulty, from `getblockchaininfo`.
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
    [
      key: "DIFFICULTY",
      value: format(ZcashExplorer.Snapshot.field("metrics", "difficulty")),
      note: ZcashExplorer.Snapshot.note("metrics", "Retargeted every block"),
      accent: MetricCard.muted()
    ]
  end

  defp format(d), do: ZcashExplorerWeb.Number.positive(d)
end
