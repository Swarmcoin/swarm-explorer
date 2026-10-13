defmodule ZcashExplorerWeb.BlockActivityLive do
  use ZcashExplorerWeb, :live_view
  alias ZcashExplorer.{Snapshot}

  def mount(_, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :update, 15_000)
    {:ok, assign(socket, metric: "size", blocks: blocks())}
  end

  def handle_info(:update, socket) do
    Process.send_after(self(), :update, 15_000)
    {:noreply, assign(socket, blocks: blocks())}
  end

  def handle_event("metric", %{"metric" => metric}, socket) when metric in ["size", "tx_count"],
    do: {:noreply, assign(socket, metric: metric)}

  def render(assigns) do
    ~L"""
    <div class="sw-history sw-card">
      <div class="sw-history-head">
        <div><h2>Block activity</h2><p>Last <%= length(@blocks) %> blocks · select a bar to inspect</p></div>
        <div class="sw-segmented" role="group" aria-label="Chart metric">
          <button type="button" phx-click="metric" phx-value-metric="size" aria-pressed="<%= @metric == "size" %>">Block size</button>
          <button type="button" phx-click="metric" phx-value-metric="tx_count" aria-pressed="<%= @metric == "tx_count" %>">Transactions</button>
        </div>
      </div>
      <%= if @blocks == [] do %>
        <p class="sw-history-unavailable">Waiting for a fresh block sample.</p>
      <% else %>
        <div class="sw-chart-scale"><span><%= max_label(@blocks, @metric) %></span><span><%= if @metric == "size", do: "BYTES PER BLOCK", else: "TRANSACTIONS PER BLOCK" %></span></div>
        <div class="sw-block-chart" role="group" aria-label="Recent blocks">
          <%= for block <- @blocks do %>
            <a href="/blocks/<%= block["height"] %>" class="sw-chart-column" aria-label="Block <%= block["height"] %>: <%= value(block, @metric) %> <%= unit(@metric) %>" style="--bar-height:<%= bar_height(block, @blocks, @metric) %>%">
              <span class="sw-chart-tip">#<%= block["height"] %><strong><%= value(block, @metric) %> <%= unit(@metric) %></strong></span>
              <span class="sw-chart-bar"></span>
            </a>
          <% end %>
        </div>
        <div class="sw-chart-axis"><span>#<%= hd(@blocks)["height"] %></span><span>OLDER → NEWER</span><span>#<%= List.last(@blocks)["height"] %></span></div>
      <% end %>
    </div>
    """
  end

  defp blocks, do: Snapshot.get("block_cache", []) |> Enum.reverse()
  defp value(block, metric), do: block[metric] || 0
  defp unit("size"), do: "bytes"
  defp unit(_), do: "transactions"
  defp maximum(blocks, metric), do: blocks |> Enum.map(&value(&1, metric)) |> Enum.max(fn -> 1 end) |> max(1)
  defp bar_height(block, blocks, metric), do: Float.round(value(block, metric) / maximum(blocks, metric) * 100, 2)
  defp max_label(blocks, metric), do: ZcashExplorerWeb.Number.decimal(maximum(blocks, metric), 0) <> " " <> unit(metric)
end
