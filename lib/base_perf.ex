defmodule BasePerf do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf

  def eval(param) do
    # prepare log file
    filename =
      "/tmp/" <>
        to_string(__MODULE__) <> "_" <> param <> "-" <> Time.to_string(Time.utc_now()) <> ".csv"

    File.write(filename, "count,time,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [self(), filename])

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
        IO.puts("Evaluation end")

      # sleep at first on the loop to justify measurement
      0 ->
        IO.puts("Evaluation start")
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
