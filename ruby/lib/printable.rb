# frozen_string_literal: true

module Printable
  # @param [String] msg
  # @param [String] msg_r
  # @return [NilClass]
  def puts_r(msg, msg_r)
    size = rjust_size(msg, msg_r)
    puts "rjust: #{size}"
    puts msg + msg_r.rjust(size)
  end

  # @param [String] msg
  # @param [String] msg_r
  # @return [Integer]
  def rjust_size(msg, msg_r)
    cols - (sanitize(msg).size + sanitize(msg_r).size - msg_r.size)
  end

  private

  # @return [Integer]
  def cols
    return @_cols if defined?(@_cols)

    require "io/console"
    _lines, @_cols = IO.console.winsize
    @_cols
  end

  # @param [String] str
  # @return [String]
  def sanitize(str)
    str.gsub(/\e\[\d+;?\d*m/, "")
  end
end
