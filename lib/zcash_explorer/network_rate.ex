defmodule ZcashExplorer.NetworkRate do
  @moduledoc "Fractional work/time estimate from a contiguous sample of public block headers."
  import Bitwise
  alias ZcashExplorer.{Rpc, Snapshot}

  def sample do
    case Rpc.getnetworksolps() do
      {:ok, n} when is_number(n) and n > 0 -> {:ok, %{"rate" => n, "source" => "Node estimate"}}
      _ ->
        blocks = Snapshot.get("block_cache", [])
        case calculate(blocks) do
          {:ok, rate} -> {:ok, %{"rate" => rate, "source" => "Estimated · #{length(blocks) - 1}-block sample"}}
          error -> error
        end
    end
  end

  def calculate(blocks) when is_list(blocks) and length(blocks) >= 2 do
    sorted = Enum.sort_by(blocks, & &1["height"], :desc)
    linked = Enum.chunk_every(sorted, 2, 1, :discard) |> Enum.all?(fn [a, b] ->
      is_integer(a["height"]) and is_integer(b["height"]) and
        a["height"] == b["height"] + 1 and is_binary(b["hash"]) and a["previousblockhash"] == b["hash"]
    end)
    times = Enum.map(sorted, & &1["timestamp"])
    work = sorted |> Enum.drop(-1) |> Enum.map(&work(&1["bits"]))
    with true <- linked and Enum.all?(times, &is_integer/1) and Enum.all?(work, &is_integer/1),
         duration when duration > 0 <- Enum.max(times) - Enum.min(times),
         total when total > 0 <- Enum.sum(work) do
      {:ok, total / duration}
    else
      _ -> {:error, :invalid_window}
    end
  end
  def calculate(_), do: {:error, :invalid_window}

  def work(bits) when is_binary(bits) and byte_size(bits) == 8 do
    with {compact, ""} <- Integer.parse(bits, 16),
         exponent when exponent in 1..32 <- compact >>> 24,
         mantissa when mantissa > 0 <- compact &&& 0x7fffff,
         0 <- compact &&& 0x800000 do
      target = if exponent <= 3, do: mantissa >>> (8 * (3 - exponent)), else: mantissa <<< (8 * (exponent - 3))
      if target > 0, do: div(1 <<< 256, target + 1), else: nil
    else
      _ -> nil
    end
  end
  def work(_), do: nil
end
