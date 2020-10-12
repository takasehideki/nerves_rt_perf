defmodule BasePerf do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  @sum_num NervesRtPerf.sum_num()
  @fib_num NervesRtPerf.fib_num()

  # obtain target name
  @target System.get_env("MIX_TARGET")

  def eval(param) do
    # prepare log file
    filename =
      (@target <> to_string(__MODULE__) <> "_" <> param <> "-" <> Time.to_string(Time.utc_now()))
      |> String.replace("Elixir.", "-")
      |> String.replace(":", "")
      # eliminate under second
      |> String.slice(0..-8)

    filepath = "/tmp/" <> filename <> ".csv"
    IO.puts("result log file: " <> filepath)

    File.write(filepath, "count,time,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [self(), filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [0, pid], [])

      _ ->
        IO.puts("Argument error")
    end
  end

  # loop for evaluation
  def eval_loop(count, pid) do
    case count do
      # write results to the log file
      n when n > NervesRtPerf.eval_loop_num() ->
        send(pid, {:ok})
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        :timer.sleep(5)
        eval_loop(count + 1, pid)

      _ ->
        # measurement point
        # {eval, _} = :timer.tc(NervesRtPerf, :fib, [])
        t1 = :erlang.monotonic_time()
        NervesRtPerf.sum(@sum_num)
        NervesRtPerf.fib(@fib_num)
        t2 = :erlang.monotonic_time()
        time = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)

        result =
          "#{count},#{time},#{Process.info(self())[:heap_size]},#{
            Process.info(self())[:garbage_collection][:minor_gcs]
          }\r\n"

        # send measurement result to output process
        send(pid, {:ok, result})
        # sleep to wait output process
        :timer.sleep(5)

        eval_loop(count + 1, pid)
    end
  end
end
