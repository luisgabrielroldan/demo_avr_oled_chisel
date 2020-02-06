defmodule DemoAvrOledChisel.Arduino do
  use GenServer

  alias Circuits.UART
  alias DemoAvrOledChisel.OLED

  require Logger

  @hex_name "arduino.hex"
  @board :pro8MHzatmega328p
  @port "ttyAMA0"
  @gpio_reset 4
  @speed 9600

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    send(self(), :update)
    {:ok, font} = Chisel.Font.load("/etc/5x8.bdf")
    OLED.clear()
    OLED.display()

    {:ok, %{port: nil, font: font, data: %{}}}
  end

  def handle_info(:update, state) do
    hex_name()
    |> AVR.update(@port, @board, gpio_reset: @gpio_reset)
    |> case do
      {:ok, _} ->
        send(self(), :ready)
        {:noreply, state}

      error ->
        # Delay for not restart too quicky
        :timer.sleep(3000)

        {:stop, error, state}
    end
  end

  def handle_info(:ready, state) do
    {:ok, port} = UART.start_link()

    port_opts = [
      speed: @speed,
      framing: Circuits.UART.Framing.FourByte
    ]

    :ok = UART.open(port, @port, port_opts)

    state = %{state | port: port}

    Process.send_after(self(), :read, 1000)
    Process.send_after(self(), :print, 1000)

    {:noreply, state}
  end

  def handle_info(:read, state) do
    UART.write(state.port, <<?A, 0>>)
    UART.write(state.port, <<?A, 1>>)
    UART.write(state.port, <<?A, 2>>)

    Process.send_after(self(), :read, 1000)

    {:noreply, state}
  end

  def handle_info(:print, state) do
    OLED.clear()

    state.data
    |> Enum.each(fn {id, voltage} ->
      {id, _} = Integer.parse(id)
      msg = "Voltage in A#{id}: #{voltage}v"
      y = id * 9 + 2
      OLED.write(msg, 0, y, state.font)
    end)

    OLED.display()

    Process.send_after(self(), :print, 1000)

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _, <<?A, analog_id, value::16-little>>}, state) do
    voltage = Float.round(value * (3.3 / 1023.0), 2)

    state = %{state | data: Map.put(state.data, to_string(analog_id), voltage)}

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _, {:error, _} = error}, state) do
    # Delay for not restart too quicky
    :timer.sleep(3000)
    {:stop, error, state}
  end

  defp hex_name() do
    priv_dir = :code.priv_dir(:demo_avr_oled_chisel)

    "#{priv_dir}/#{@hex_name}"
  end
end
