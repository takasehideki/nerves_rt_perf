defmodule NervesRtPerf.GcMin.Sleep do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  @eval_loop_num NervesRtPerf.eval_loop_num()
  @sleep_interval NervesRtPerf.sleep_interval()

  # obtain target name
  @target System.get_env("MIX_TARGET")

  def eval(param) do
    # prepare log file
    filename =
      (@target <> to_string(__MODULE__) <> "_" <> param <> "-" <> Time.to_string(Time.utc_now()))
      |> String.replace("Elixir.NervesRtPerf.", "-")
      |> String.replace(".", "-")
      |> String.replace(":", "")
      # eliminate under second
      |> String.slice(0..-8)

    filepath = "/tmp/" <> filename <> ".csv"
    IO.puts("result log file: " <> filepath)

    File.write(filepath, "count,time,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [])

      "34" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [{:min_heap_size, 34}])

      "233" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [{:min_heap_size, 233}])

      "6765" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [{:min_heap_size, 6765}])

      "196418" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [{:min_heap_size, 196_418}])

      _ ->
        IO.puts("Argument error")
    end
  end

  # loop for evaluation
  def eval_loop(count, pid) do
    # sleep on each iteration
    :timer.sleep(5)

    case count do
      # write results to the log file
      n when n > @eval_loop_num ->
        send(pid, {:ok})
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        :timer.sleep(@sleep_interval)
        :timer.sleep(5)
        eval_loop(count + 1, pid)

      _ ->
        # measurement point
        t1 = :erlang.monotonic_time()
        :timer.sleep(@sleep_interval)
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
