defmodule ZcashExplorerWeb.LayoutView do
  @moduledoc """
  SWARM change: `bg_class/1` branched on mainnet vs testnet to pick a Tailwind
  palette. There is one network and one theme here, so the page background is
  set once in the stylesheet and the helper is gone.

  The network is stated three times on every page, all from the one runtime
  switch `ZcashExplorer.Swarm.mainnet?/0`: the ribbon above the header
  (`network_ribbon.html`), the chip beside the wordmark (`header.html`) and the
  start of the document title (`document_title/1`).
  """
  use ZcashExplorerWeb, :view

  alias ZcashExplorer.Swarm

  @doc """
  The `<title>` of every page: the network first, then the page.

      document_title(nil)                  #=> "SWARM Testnet Explorer"
      document_title("SWARM block 343")    #=> "SWARM Testnet Explorer · Block 343"
      document_title("Nothing found")      #=> "SWARM Testnet Explorer · Nothing found"

  Controllers title their pages "SWARM block 343"; the prefix already says
  SWARM, so a leading project name is dropped rather than said twice, and the
  first letter of what remains is capitalised.
  """
  @spec document_title(String.t() | nil) :: String.t()
  def document_title(page_title) do
    case page_part(page_title) do
      "" -> Swarm.explorer_title()
      part -> Swarm.explorer_title() <> " · " <> part
    end
  end

  @doc """
  The title of an error page Phoenix renders itself (config :render_errors):
  those renders carry the HTTP status and the exception, and no page title.
  `nil` for every other page.
  """
  @spec error_title(map()) :: String.t() | nil
  def error_title(%{status: status, reason: _}) when is_integer(status),
    do: Plug.Conn.Status.reason_phrase(status)

  def error_title(_assigns), do: nil

  defp page_part(nil), do: ""

  defp page_part(title) do
    title
    |> to_string()
    |> String.trim()
    |> String.replace_prefix(Swarm.project_name() <> " ", "")
    |> upcase_first()
  end

  defp upcase_first(""), do: ""

  defp upcase_first(text) do
    {first, rest} = String.split_at(text, 1)
    String.upcase(first) <> rest
  end
end
