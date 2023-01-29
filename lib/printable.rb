# frozen_string_literal: true

module Printable
  # @param [String] msg
  # @param [String] msg_r
  # @return [NilClass]
  def puts_r(msg, msg_r)
    size = rjust_size(msg, msg_r)
    puts msg + msg_r.rjust(size)
  end

  # @param [String] msg
  # @param [String] msg_r
  # @return [Integer]
  def rjust_size(msg, msg_r)
    sanitized = ->(str) { str.sanitize_colored.size + str.scan(/\p{Hangul}/).size }
    cols - sanitized.call(msg) - sanitized.call(msg_r) + msg_r.size
  end

  # @return [Integer]
  def cols
    return @_cols if defined?(@_cols)

    require "io/console"
    _lines, @_cols = IO.console.winsize
    @_cols
  end
end
