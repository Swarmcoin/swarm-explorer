defmodule ZcashExplorerWeb.Number do
  @moduledoc "Readable numbers without rounding positive difficulty to zero."
  def positive(n) when is_number(n) and n > 0 and n < 0.000001,
    do: :erlang.float_to_binary(n / 1, [{:scientific, 4}])
  def positive(n) when is_number(n) and n > 0, do: decimal(n, 6)
  def positive(_), do: "—"

  def decimal(n, precision \\ 2)
  def decimal(n, precision) when is_number(n) do
    [whole | fraction] = :erlang.float_to_binary(n / 1, [:compact, {:decimals, precision}]) |> String.split(".")
    whole = Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, whole, ",")
    suffix = fraction |> Enum.join() |> String.trim_trailing("0")
    whole <> if(suffix == "", do: "", else: "." <> suffix)
  end
  def decimal(_, _), do: "—"
end
