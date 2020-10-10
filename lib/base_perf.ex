defmodule BasePerf do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
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
    pid = spawn(NervesRtPerf, :output, [self(), filepath])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [0, "", pid], [])

      _ ->
        IO.puts("Argument error")
    end
  end

  # loop for evaluation
  def eval_loop(count, results, pid) do
    case count do
      n when n > NervesRtPerf.eval_num() ->
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))

      # sleep at first on the loop to justify measurement
      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        :timer.sleep(5)
        eval_loop(count + 1, results, pid)

      _ ->
        # measurement point
        time_before = :erlang.now()
        NervesRtPerf.fib()
        time_after = :erlang.now()

        result =
          "#{count},#{:timer.now_diff(time_after, time_before)},#{
            Process.info(self())[:heap_size]
          },#{Process.info(self())[:garbage_collection][:minor_gcs]}\r\n"

        case rem(count, NervesRtPerf.logout_num()) do
          # send measurement log to output process
          0 ->
            send(pid, {:ok, results <> result})
            # sleep to wait log output
            :timer.sleep(1000)

            eval_loop(count + 1, result, pid)

          _ ->
            eval_loop(count + 1, results <> result, pid)
        end
    end
  end
end
