defmodule NervesRtPerf.Base.Nodeconnect do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  @eval_loop_num NervesRtPerf.eval_loop_num()

  # obtain target name
  @target System.get_env("MIX_TARGET")

  def eval(param, name, conn_node_ip, cookie) do
    # prepare log file
    filename =
      (@target <> to_string(__MODULE__) <> "_" <> param <> "-" <> Time.to_string(Time.utc_now()) <> "_" <> name)
      |> String.replace("Elixir.NervesRtPerf.", "-")
      |> String.replace(".", "-")
      |> String.replace(":", "")
      # eliminate under second
      |> String.slice(0..-8)

    filepath = "/tmp/" <> filename <> ".csv"
    IO.puts("result log file: " <> filepath)

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [filepath, ""])

    case name do
      "Alice" ->
        # time_1: デバイス内で送信開始から送信終了までにかかった時間, time_2: 送信から受信終了までにかかった時間,
        File.write(filepath, "count,time_1,time_2,heap_size,minor_gcs\r\n")
        conn_node = NervesRtPerf.NodeConnect.start(name, conn_node_ip, cookie)

        case param do
          "normal" ->
            ppid = Node.spawn(conn_node, __MODULE__, :eval_loop_alice, [1, pid, self()])
            Process.spawn(__MODULE__, :eval_loop_alice, [1, pid, ppid], [])

          _ ->
            IO.puts("Argument error")
        end

      "Bob" ->
        File.write(filepath, "count,time_1,heap_size,minor_gcs\r\n")
        _conn_node = NervesRtPerf.NodeConnect.start(name, conn_node_ip, cookie)

      _ ->
        IO.puts("Argument Error")
    end
  end

  # loop for evaluation
  def eval_loop_alice(count, pid, ppid) do
    # pid: output
    # ppid: Process in node "Bob"

    # sleep on each iteration
    :timer.sleep(50)

    case count do
      # write results to the log file
      n when n > @eval_loop_num ->
        send(pid, :ok)
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        send(ppid, {:hi, self()})

        receive do
          :accept -> nil
        end
        :timer.sleep(50)
        eval_loop_alice(count + 1, pid, ppid)

      _ ->
        # measurement point
        t1 = :erlang.monotonic_time()
        send(ppid, {:hi, self()})
        t2 = :erlang.monotonic_time()
        receive do
          :accept -> nil
        end
        t3 = :erlang.monotonic_time()

        time_1 = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)
        time_2 = :erlang.convert_time_unit(t3 - t2, :native, :microsecond)

        result =
          "#{count},#{time_1},#{time_2},#{Process.info(self())[:heap_size]},#{
            Process.info(self())[:garbage_collection][:minor_gcs]
          }\r\n"

        # send measurement result to output process
        send(pid, {:ok, result})
        # sleep to wait output process
        :timer.sleep(50)

        eval_loop_alice(count + 1, pid, ppid)
    end
  end

  def eval_loop_bob(count, pid, ppid) do
    # Called by Alice after both Alice and Bob started.
    # pid: output
    # ppid: Process in node "Alice"
    case count do
      0 ->
        # ignore evaluation for the first time to avoid cache influence
        receive do
          :hi ->
            send(ppid, :accept)
        end
        eval_loop_bob(count + 1, pid, ppid)

      _ ->
        receive do
          :hi ->
            t1 = :erlang.monotonic_time()
            send(ppid, :accept)
            t2 = :erlang.monotonic_time()

            time = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)

            result =
              "#{count},#{time},#{Process.info(self())[:heap_size]},#{
                Process.info(self())[:garbage_collection][:minor_gcs]
              }\r\n"

            # send measurement result to output process
            send(pid, {:ok, result})
        end
        eval_loop_bob(count + 1, pid, ppid)
    end
    case count do
      n when n >= @eval_loop_num ->
        Node.stop
      _ ->
        nil
    end
  end
end
