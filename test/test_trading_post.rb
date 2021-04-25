#!/usr/bin/env ruby
require 'pp'
require_relative '../lib/trading_post.rb'

t = TradingPost.new()
# pp t.tables
# pp t.modifiers
t.print_trading_post