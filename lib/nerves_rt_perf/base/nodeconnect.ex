defmodule NervesRtPerf.Base.Nodeconnect do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  @eval_loop_num NervesRtPerf.eval_loop_num()

  # obtain target name
  @target System.get_env("MIX_TARGET")

  def eval(param, name) do
    case param do
      "normal" ->

        case name do
          "Alice" ->
            # prepare log file for Alice
            filename_alice =
              (@target <> to_string(__MODULE__)  <> "_Alice_" <> param <> "-" <> Time.to_string(Time.utc_now()))
              |> String.replace("Elixir.NervesRtPerf.", "-")
              |> String.replace(".", "-")
              |> String.replace(":", "")
              # eliminate under second
              |> String.slice(0..-8)
            filepath_alice = "/tmp/" <> filename_alice <> ".csv"
            IO.puts("result log file in Alice: " <> filepath_alice)
            # generate process for output of measurement logs
            alice_output_pid = spawn(NervesRtPerf, :output, [filepath_alice, ""])
            # time_1: デバイス内で送信開始から送信終了までにかかった時間, time_2: 送信終了から受信終了までにかかった時間
            File.write(filepath_alice, "count,time_1,time_2,heap_size,minor_gcs\r\n")

            # prepare log file for Bob
            filename_bob =
              (@target <> to_string(__MODULE__)  <> "_Bob_" <> param <> "-" <> Time.to_string(Time.utc_now()))
              |> String.replace("Elixir.NervesRtPerf.", "-")
              |> String.replace(".", "-")
              |> String.replace(":", "")
              # eliminate under second
              |> String.slice(0..-8)
            filepath_bob = "/tmp/" <> filename_bob <> ".csv"
            IO.puts("result log file in Bob: " <> filepath_bob)
            # generate process for output of measurement logs
            bob_output_pid = spawn(NervesRtPerf, :output, [filepath_bob, ""])
            # time: デバイス内で受信完了してから送信終了までにかかった時間
            File.write(filepath_alice, "count,time,heap_size,minor_gcs\r\n")

            # start node and connect with "Bob"
            conn_node = NervesRtPerf.NodeConnect.start(name)

            # start process in "Bob"
            ppid = Node.spawn(conn_node, __MODULE__, :eval_loop_bob, [0, bob_output_pid])

            # start evaluation process in "Alice"
            Process.spawn(__MODULE__, :eval_loop_alice, [0, alice_output_pid, ppid], [])

          "Bob" ->
            # start node
            _conn_node = NervesRtPerf.NodeConnect.start(name)

          _ ->
            IO.puts("Argument Error")
        end

      _ ->
        IO.puts("Argument error")
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
        Node.stop
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        send(ppid, {:hi,self()})

        receive do
          :accept ->
            :timer.sleep(50)
            eval_loop_alice(count + 1, pid, ppid)
        end

      _ ->
        # measurement point
        t1 = :erlang.monotonic_time()
        send(ppid, {:hi,self()})
        t2 = :erlang.monotonic_time()
        receive do
          :accept -> nil
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
  end

  def eval_loop_bob(count, pid) do
    # Called by Alice after both Alice and Bob started.
    # pid: output
    # ppid: Process in node "Alice"
    case count do
      0 ->
        # ignore evaluation for the first time to avoid cache influence
        receive do
          {:hi, ppid} ->
            send(ppid, :accept)
        end
        eval_loop_bob(count + 1, pid)

      _ ->
        receive do
          {:hi, ppid} ->
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

            if count >= @eval_loop_num do
              Node.stop
            end
        end
        eval_loop_bob(count + 1, pid)
    end
  end
end
