defmodule NervesRtPerf do
  # macro definitions for const value
  # loop count for evaluation
  defmacro eval_num, do: 1_000_000
  # output count to log file for evaluation
  defmacro logout_num, do: 1_000

  def output(pid, filename) do
    receive do
      {:ok, results} ->
        File.write(filename, results, [:append])
        # IO.inspect(result)
        output(pid, filename)
    end
  end

  @sum_num 15
  def sum() do
    1..@sum_num
    |> Enum.reduce(fn x, acc -> x + acc end)
  end

  @fib_num 25
  def fib(0) do
    0
  end

  def fib(1) do
    1
  end

  def fib(n) do
    fib(n - 1) + fib(n - 2)
  end

  def fib do
    fib(@fib_num)
  end
end
