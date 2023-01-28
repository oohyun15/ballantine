module Printable
  # @note
  # @param [Object] msg
  # @param [Object] rjust
  # @return [NilClass]
  def puts_r(msg, rjust)
    # convert to String
    msg = msg.to_s
    rjust = rjust.to_s

    size = cols - msg.size

    puts msg + rjust.rjust(size)
  end

  private

  # @return [Integer]
  def cols
    return @_cols if defined?(@_cols)

    require "io/console"
    _lines, @_cols = IO.console.winsize
    @_cols
  end
end
