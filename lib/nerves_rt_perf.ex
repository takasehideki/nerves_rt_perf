defmodule NervesRtPerf do
  # macro definition for evaluation loop count
  defmacro eval_loop_num, do: 10_000

  def output(filepath, results) do
    receive do
      {:ok, result} ->
        # IO.inspect(result)
        results = results <> result
        output(filepath, results)

      {:ok} ->
        File.write(filepath, results, [:append])
    end
  end

  ## function for evaluation
  defmacro sum_num, do: 4000

  def sum(n) do
    1..n
    |> Enum.reduce(fn x, acc -> x + acc end)
  end

  defmacro fib_num, do: 20

  def fib(0) do
    0
  end

  def fib(1) do
    1
  end

  def fib(n) do
    fib(n - 1) + fib(n - 2)
  end

  defmacro sleep_interval, do: 5
end

defmodule NervesRtPerf.Driver do
  require NervesRtPerf.Base.Gpioread
  require NervesRtPerf.Base.Gpiowrite
  require NervesRtPerf.Base.Nothing

  require NervesRtPerf.CpuFreq.Gpioread
  require NervesRtPerf.CpuFreq.Gpiowrite
  require NervesRtPerf.CpuFreq.Nothing

  require NervesRtPerf.GcFsa.Gpioread
  require NervesRtPerf.GcFsa.Gpiowrite
  require NervesRtPerf.GcFsa.Nothing

  require NervesRtPerf.GcMin.Gpioread
  require NervesRtPerf.GcMin.Gpiowrite
  require NervesRtPerf.GcMin.Nothing

  require NervesRtPerf.Priority.Gpioread
  require NervesRtPerf.Priority.Gpiowrite
  require NervesRtPerf.Priority.Nothing

  def eval_driver(param) do

    case param do
      "write" -> # writeとnothing
        # Base
        IO.puts("---------- Base ----------")

        IO.puts(Time.to_string(Time.utc_now()))
        NervesRtPerf.Base.Gpiowrite.eval("normal")
        :timer.sleep(600000)# 10分
        IO.puts("NervesRtPerf.Base.Gpiowrite finished")

        IO.puts(Time.to_string(Time.utc_now()))
        NervesRtPerf.Base.Nothing.eval("normal")
        :timer.sleep(240000)# 4分
        IO.puts("NervesRtPerf.Base.Nothing finished")

        # cpu_freq
        IO.puts("---------- CpuFreq ----------")
        var_list = ["normal",  "performance", "powersave"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.CpuFreq.Gpiowrite.eval(s)
          :timer.sleep(600000)# 10分
        end
        IO.puts("NervesRtPerf.CpuFreq.Gpiowrite finished")

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.CpuFreq.Nothing.eval(s)
          :timer.sleep(180000)# 3分
        end
        IO.puts("NervesRtPerf.CpuFreq.Nothing finished")


        # gc_fsa
        IO.puts("---------- GcFsa ----------")
        var_list = ["normal",  "zero", "8191", "32767", "65535", "131071"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcFsa.Gpiowrite.eval(s)
          :timer.sleep(600000)# 10分
        end
        IO.puts("NervesRtPerf.GcFsa.Gpiowrite finished")

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcFsa.Nothing.eval(s)
          :timer.sleep(180000)# 3分
        end
        IO.puts("NervesRtPerf.GcFsa.Nothing finished")


        # gc_min
        IO.puts("---------- GcMin ----------")
        var_list = ["normal",  "34", "233", "6765", "196418"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcMin.Gpiowrite.eval(s)
          :timer.sleep(600000)# 10分
        end
        IO.puts("NervesRtPerf.GcMin.Gpiowrite finished")

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcMin.Nothing.eval(s)
          :timer.sleep(180000)# 3分
        end
        IO.puts("NervesRtPerf.GcMin.Nothing finished")


        # priority
        IO.puts("---------- Priority ----------")
        var_list = ["normal", "low", "high"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.Priority.Gpiowrite.eval(s)
          :timer.sleep(600000)# 10分
        end
        IO.puts("NervesRtPerf.Priority.Gpiowrite finished")

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.Priority.Nothing.eval(s)
          :timer.sleep(180000)# 3分
        end
        IO.puts("NervesRtPerf.Priority.Nothing finished")

      "read" ->
        # Base
        IO.puts("---------- Base ----------")

        IO.puts(Time.to_string(Time.utc_now()))
        NervesRtPerf.Base.Gpioread.eval("normal")
        :timer.sleep(300000)# 5分
        IO.puts("NervesRtPerf.Base.Gpioread finished")

        # cpu_freq
        IO.puts("---------- CpuFreq ----------")
        var_list = ["normal",  "performance", "powersave"]
        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.CpuFreq.Gpioread.eval(s)
          :timer.sleep(300000)# 5分
        end
        IO.puts("NervesRtPerf.CpuFreq.Gpioread finished")

        # GcFsa
        IO.puts("---------- GcFsa ----------")
        var_list = ["normal",  "zero", "8191", "32767", "65535", "131071"]
        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcFsa.Gpioread.eval(s)
          :timer.sleep(300000)# 5分
        end
        IO.puts("NervesRtPerf.GcFsa.Gpioread finished")

        # gc_min
        IO.puts("---------- GcMin ----------")
        var_list = ["normal",  "34", "233", "6765", "196418"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.GcMin.Gpioread.eval(s)
          :timer.sleep(300000)# 5分
        end
        IO.puts("NervesRtPerf.GcMin.Gpioread finished")

        # priority
        IO.puts("---------- Priority ----------")
        var_list = ["normal", "low", "high"]

        for s <- var_list do
          IO.puts(Time.to_string(Time.utc_now()))
          NervesRtPerf.Priority.Gpioread.eval(s)
          :timer.sleep(300000)# 5分
        end
        IO.puts("NervesRtPerf.Priority.Gpioread finished")
    end
  end
end

defmodule NervesRtPerf.NodeConnect do
  # obtain IP address
  @my_ip System.get_env("MY_IP")
  @conn_ip System.get_env("CONN_IP")

  # obtain cookie
  @cookie System.get_env("COOKIE")

  def start(name) do
    # Node start
    System.cmd("epmd", ["-daemon"])
    case name do
      "Alice" ->
        Node.start(:"#{name}@#{@my_ip}")
      "Bob" ->
        Node.start(:"#{name}@#{@my_ip}")
      _ ->
        IO.puts("Argument Error")
    end
    Node.set_cookie(:"#{@cookie}")

    # Node connect
    # It doesn't work well unless Node "Bob" is started before "Alice" starts.
    case name do
      "Alice" ->
        conn_node = :"Bob@#{@conn_ip}"
        Node.connect(conn_node)
        conn_node
      "Bob" ->
        conn_node = :"Alice@#{@conn_ip}"
        conn_node
      _ ->
        IO.puts("Argument Error")
    end
  end

end
