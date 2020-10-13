defmodule NervesRtPerf.Spawn.Recursive do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  @eval_loop_num NervesRtPerf.eval_loop_num()
  @sum_num NervesRtPerf.sum_num()
  @fib_num NervesRtPerf.fib_num()

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

    # generate process for evaluation
    pid_output = spawn(NervesRtPerf, :output, [filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [0, pid_output], [])

      _ ->
        IO.puts("Argument error")
    end
  end

  def eval_spawn(pid_output) do
    receive do
      {:ok, count} ->
        # measurement point
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
        send(pid_output, {:ok, result})

        eval_spawn(pid_output)
    end
  end

  # loop for evaluation
  def eval_loop(count, pid_output) do
    case count do
      # write results to the log file
      n when n > @eval_loop_num ->
        send(pid_output, {:ok})
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        pid_spawn = spawn(__MODULE__, :eval_spawn, [pid_output])
        send(pid_spawn, {:ok, count})
        :timer.sleep(5)
        eval_loop(count + 1, pid_output)

      _ ->
        pid_spawn = spawn(__MODULE__, :eval_spawn, [pid_output])
        send(pid_spawn, {:ok, count})
        :timer.sleep(5)

        eval_loop(count + 1, pid_output)
    end
  end
end
