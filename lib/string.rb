# frozen_string_literal: true

# extension for strings
class String
  NC     = "\e[0m"
  GRAY   = "\e[1;30m"
  RED    = "\e[1;31m"
  GREEN  = "\e[1;32m"
  YELLOW = "\e[1;33m"
  BLUE   = "\e[1;34m"
  CYAN   = "\e[1;36m"

  def gray   = "#{GRAY}#{self}#{NC}"
  def red    = "#{RED}#{self}#{NC}"
  def green  = "#{GREEN}#{self}#{NC}"
  def yellow = "#{YELLOW}#{self}#{NC}"
  def blue   = "#{BLUE}#{self}#{NC}"
  def cyan   = "#{CYAN}#{self}#{NC}"

  def sanitize_colored = gsub(/\e\[\d+;?\d*m/, "")
end
