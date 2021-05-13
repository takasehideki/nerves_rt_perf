defmodule NervesRtPerf.Base.Gpiowrite do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  alias Circuits.GPIO
  @eval_loop_num NervesRtPerf.eval_loop_num()

  # obtain target name
  @target System.get_env("MIX_TARGET")

  # obtain pin number
  @gpio_pin System.get_env("GPIO_PIN")

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

    File.write(filepath, "count,time_for_write_1,time_for_write_0,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [1, pid], [])

      _ ->
        IO.puts("Argument error")
    end
  end

  # loop for evaluation
  def eval_loop(count, pid) do
    # sleep on each iteration
    :timer.sleep(5)

    # open the pin
    {pin_num, _} = Integer.parse(@gpio_pin)
    {:ok, gpio} = GPIO.open(pin_num, :output)

    case count do
      # write results to the log file
      n when n > @eval_loop_num ->
        send(pid, {:ok})
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        GPIO.write(gpio, 1)
        :timer.sleep(5)
        GPIO.write(gpio, 0)
        :timer.sleep(5)
        eval_loop(count + 1, pid)

      _ ->
        # measurement point
        t1 = :erlang.monotonic_time()
        GPIO.write(gpio, 1)
        t2 = :erlang.monotonic_time()
        GPIO.write(gpio, 0)
        t3 = :erlang.monotonic_time()
        time_1 = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)
        time_0 = :erlang.convert_time_unit(t3 - t2, :native, :microsecond)

        result =
          "#{count},#{time_1},#{time_0},#{Process.info(self())[:heap_size]},#{
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
