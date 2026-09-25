defmodule ZcashExplorer.Hostnames do
  @moduledoc """
  The public hostnames this explorer is served under, from `EXPLORER_HOSTNAME`.

  One instance answers under several names at once: the canonical
  `explore.swarm.green`, the network-specific `testnet.explore.swarm.green`,
  and, during the interim, the light-wallet name on port 8443. Phoenix checks
  the `Origin` header of every LiveView websocket against an allowlist, and an
  allowlist built from a single name means that on every other name the pages
  load and the live tiles silently never connect, with nothing in any log.
  Until this module existed the reverse proxy had to rewrite the `Origin`
  header to the one accepted name (server-access note "Explorer subdomains
  2026-09-25", section 4.2).

  `EXPLORER_HOSTNAME` is therefore a comma-separated list. The first entry is
  the canonical name and feeds the generated URLs; every entry feeds
  `check_origin`. A single name, as before, is a list of one.
  """

  @default "localhost"

  @doc """
  Parses the value of `EXPLORER_HOSTNAME` into a list of bare hostnames.

    * Entries are separated by commas; whitespace around them is ignored.
    * A scheme prefix (`https://`) and trailing slashes are stripped, as the
      single-name form always allowed.
    * Names are lower-cased: DNS is case-insensitive and browsers send the
      `Origin` header in lower case.
    * Duplicates are dropped; the order is otherwise kept.
    * `nil`, the variable being unset, gives `["localhost"]`.

  An entry that is not a bare hostname - it still has a path, a port, a
  wildcard or whitespace inside it - and a value that names no host at all
  raise an `ArgumentError` naming the variable, so a typo stops the boot
  instead of producing an allowlist that quietly matches nothing. The port of
  the public URL is `EXPLORER_PORT`; the origin check accepts every port for
  each listed name, which is what lets the same list serve `:443` and the
  interim `:8443` endpoint.
  """
  @spec parse(String.t() | nil) :: [String.t(), ...]
  def parse(nil), do: [@default]

  def parse(value) when is_binary(value) do
    entries =
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if entries == [] do
      raise ArgumentError,
            "EXPLORER_HOSTNAME is set but names no host: #{inspect(value)}. " <>
              "Unset it to serve localhost, or give one or more hostnames separated by commas."
    end

    entries
    |> Enum.map(&normalise!/1)
    |> Enum.uniq()
  end

  @doc """
  The canonical hostname: the first entry, the one generated URLs carry.
  """
  @spec primary([String.t(), ...]) :: String.t()
  def primary([host | _]), do: host

  @doc """
  The `check_origin` allowlist the endpoint is given.

  `//host` allows that host on any scheme and any port, which is what makes the
  interim `lwd.swarm.green:8443` endpoint work from the bare name. The two
  loopback entries are for the container's own health check and a local run.
  """
  @spec check_origin([String.t(), ...], String.t() | pos_integer()) :: [String.t(), ...]
  def check_origin(hosts, internal_port) when is_list(hosts) and hosts != [] do
    (Enum.map(hosts, &("//" <> &1)) ++ ["//localhost", "http://127.0.0.1:#{internal_port}"])
    |> Enum.uniq()
  end

  defp normalise!(entry) do
    host =
      entry
      |> String.replace(~r{^[a-z][a-z0-9+.-]*://}i, "")
      |> String.trim_trailing("/")
      |> String.downcase()

    cond do
      host == "" ->
        raise ArgumentError, "EXPLORER_HOSTNAME entry #{inspect(entry)} names no host"

      String.contains?(host, ["/", ":", "*", " ", "\t"]) ->
        raise ArgumentError,
              "EXPLORER_HOSTNAME entry #{inspect(entry)} is not a bare hostname. " <>
                "Give the name only, without scheme, port or path " <>
                "(the public port is EXPLORER_PORT); separate several names with commas."

      true ->
        host
    end
  end
end
