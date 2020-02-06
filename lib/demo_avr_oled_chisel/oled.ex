defmodule DemoAvrOledChisel.OLED do
  use OLED.Display, app: :demo_avr_oled_chisel

  alias Chisel.Renderer

  def write(text, x, y, font) do
    put_pixel = fn x, y ->
      __MODULE__.put_pixel(x, y)
    end

    Renderer.draw_text(text, x, y, font, put_pixel)
  end
end
