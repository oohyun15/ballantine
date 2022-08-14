#!/usr/bin/env ruby

# @override
class String
  NC= "\e[0m"
  GRAY= "\e[1;30m"
  RED= "\e[1;31m"
  GREEN= "\e[1;32m"
  YELLOW= "\e[1;33m"
  BLUE= "\e[1;34m"
  CYAN= "\e[1;36m"

  def gray;   "#{GRAY}#{self}#{NC}"   end
  def red;    "#{RED}#{self}#{NC}"    end
  def green;  "#{GREEN}#{self}#{NC}"  end
  def yellow; "#{YELLOW}#{self}#{NC}" end
  def blue;   "#{BLUE}#{self}#{NC}"   end
  def cyan;   "#{CYAN}#{self}#{NC}"   end
end
