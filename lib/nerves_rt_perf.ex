defmodule NervesRtPerf do
  # macro definition for evaluation loop count
  defmacro eval_loop_num, do: 100_000

  def output(pid, filepath, results) do
    receive do
      {:ok, result} ->
        # IO.inspect(result)
        results = results <> result
        output(pid, filepath, results)

      {:ok} ->
        File.write(filepath, results, [:append])
    end
  end

  ## function for evaluation
  defmacro sum_num, do: 15

  def sum(n) do
    1..n
    |> Enum.reduce(fn x, acc -> x + acc end)
  end

  defmacro fib_num, do: 15

  def fib(0) do
    0
  end

  def fib(1) do
    1
  end

  def fib(n) do
    fib(n - 1) + fib(n - 2)
  end
end
