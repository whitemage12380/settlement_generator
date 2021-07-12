#!/usr/bin/env ruby
require 'pp'
require_relative '../lib/trading_post'
require_relative '../lib/exporter_markdown'

t = Settlements::TradingPost.new()
# pp t.tables
# pp t.modifiers
t.print
Settlements::ExporterMarkdown.export_to_markdown(t)