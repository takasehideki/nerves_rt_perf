defmodule NervesRtPerf.CpuFreq.Gpioread do
  # macro setting for const value (defined by NervesRtPerf)
  require NervesRtPerf
  alias Circuits.GPIO
  @eval_loop_num NervesRtPerf.eval_loop_num()
  @governor_file "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"

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

    File.write(filepath, "count,time,onoff,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [0, pid], [])

      "performance" ->
        File.write(@governor_file, "performance")
        :timer.sleep(100)
        Process.spawn(__MODULE__, :eval_loop, [0, pid], [])

      "powersave" ->
        File.write(@governor_file, "powersave")
        :timer.sleep(100)
        Process.spawn(__MODULE__, :eval_loop, [0, pid], [])

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
    {:ok, gpio} = GPIO.open(pin_num, :input)

    case count do
      # write results to the log file
      n when n > @eval_loop_num ->
        send(pid, {:ok})
        IO.puts("Evaluation end:" <> Time.to_string(Time.utc_now()))
        GPIO.close(gpio)
        :ok

      0 ->
        IO.puts("Evaluation start:" <> Time.to_string(Time.utc_now()))
        # ignore evaluation for the first time to avoid cache influence
        GPIO.read(gpio)
        :timer.sleep(5)
        eval_loop(count + 1, pid)

      _ ->
        # measurement point
        t1 = :erlang.monotonic_time()
        onoff = GPIO.read(gpio)
        t2 = :erlang.monotonic_time()
        time = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)

        result =
          "#{count},#{time},#{onoff},#{Process.info(self())[:heap_size]},#{
            Process.info(self())[:garbage_collection][:minor_gcs]
          }\r\n"

        # close gpio pin
        GPIO.close(gpio)

        # send measurement result to output process
        send(pid, {:ok, result})
        # sleep to wait output process
        :timer.sleep(5)

        eval_loop(count + 1, pid)
    end
  end
end
