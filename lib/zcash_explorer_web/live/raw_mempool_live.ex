defmodule ZcashExplorerWeb.RawMempoolLive do
  use ZcashExplorerWeb, :live_view
  def render(assigns) do
    ~L"""
    <section class="sw-card sw-data-panel">
      <div class="sw-panel-heading"><h2>Pending transactions</h2><span class="sw-caption"><%= @note %></span></div>
      <%= cond do %>
        <% is_nil(@rows) -> %><div class="sw-empty"><span aria-hidden="true">◌</span><h3>Mempool data is unavailable</h3><p>Waiting for a fresh node response. This does not mean the mempool is empty.</p></div>
        <% @rows == [] -> %><div class="sw-empty"><span aria-hidden="true">✓</span><h3>Nothing waiting right now</h3><p>The node’s mempool is empty. New pending transactions appear here automatically.</p><a href="/blocks" class="sw-text-link">Explore confirmed blocks →</a></div>
        <% true -> %><div class="sw-table-scroll" tabindex="0" role="region" aria-label="Pending transactions"><table><thead><tr><th>Transaction ID</th><th>Entry height</th><th>Seen at</th><th>Fee</th><th>Bytes</th></tr></thead><tbody>
        <%= for tx <- @rows do %><tr><td class="sw-mono"><a href="/transactions/<%= tx["txid"] %>"><%= tx["txid"] %></a></td><td><%= tx["info"]["height"] || "—" %></td><td><%= time(tx["info"]["time"]) %></td><td><%= ZcashExplorerWeb.Number.decimal(tx["info"]["fee"], 8) %></td><td><%= tx["info"]["size"] || "—" %></td></tr><% end %>
        </tbody></table></div>
      <% end %>
    </section>
    """
  end
  def mount(_, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 5000)
    {:ok, assign(socket, figures())}
  end
  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 5000)
    {:noreply, assign(socket, figures())}
  end
  defp figures, do: [rows: ZcashExplorer.Snapshot.get("raw_mempool", nil, 20), note: ZcashExplorer.Snapshot.note("raw_mempool", "Node response")]
  defp time(n) when is_integer(n), do: ZcashExplorerWeb.BlockView.mined_time_rel(n)
  defp time(_), do: "—"
end
