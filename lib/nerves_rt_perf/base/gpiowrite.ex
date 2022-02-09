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

    File.write(filepath, "count,time_for_0,time_for_1,time_for_0to1,time_for_1to0,heap_size,minor_gcs\r\n")

    # generate process for output of measurement logs
    pid = spawn(NervesRtPerf, :output, [filepath, ""])

    case param do
      "normal" ->
        Process.spawn(__MODULE__, :eval_loop, [0, pid], [])

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
        # open the pin
        {pin_num, _} = Integer.parse(@gpio_pin)
        {:ok, gpio} = GPIO.open(pin_num, :output)
        # write 1
        GPIO.write(gpio, 1)
        :timer.sleep(5)
        # rewrite 1 to 0
        GPIO.write(gpio, 0)
        :timer.sleep(5)
        GPIO.close(gpio)

        # open the pin
        {pin_num, _} = Integer.parse(@gpio_pin)
        {:ok, gpio} = GPIO.open(pin_num, :output)
        # write 0
        GPIO.write(gpio, 0)
        :timer.sleep(5)
        # rewrite 0 to 1
        GPIO.write(gpio, 1)
        :timer.sleep(5)
        GPIO.close(gpio)
        eval_loop(count + 1, pid)

      _ ->
        # measurement point
        # open the pin
        {pin_num, _} = Integer.parse(@gpio_pin)
        {:ok, gpio} = GPIO.open(pin_num, :output)
        # write 1
        t1 = :erlang.monotonic_time()
        GPIO.write(gpio, 1)
        t2 = :erlang.monotonic_time()
        :timer.sleep(5)
        # 1 to 0
        t3 = :erlang.monotonic_time()
        GPIO.write(gpio, 0)
        t4 = :erlang.monotonic_time()
        :timer.sleep(5)
        GPIO.close(gpio)

        # open the pin
        {pin_num, _} = Integer.parse(@gpio_pin)
        {:ok, gpio} = GPIO.open(pin_num, :output)
        # write 0
        t5 = :erlang.monotonic_time()
        GPIO.write(gpio, 0)
        t6 = :erlang.monotonic_time()
        :timer.sleep(5)
        # 0 to 1
        t7 = :erlang.monotonic_time()
        GPIO.write(gpio, 1)
        t8 = :erlang.monotonic_time()
        :timer.sleep(5)
        GPIO.close(gpio)

        time_0 = :erlang.convert_time_unit(t6 - t5, :native, :microsecond)
        time_1 = :erlang.convert_time_unit(t2 - t1, :native, :microsecond)
        time_1to0 = :erlang.convert_time_unit(t4 - t3, :native, :microsecond)
        time_0to1 = :erlang.convert_time_unit(t8 - t7, :native, :microsecond)

        result =
          "#{count},#{time_0},#{time_1},#{time_0to1},#{time_1to0},#{Process.info(self())[:heap_size]},#{
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
