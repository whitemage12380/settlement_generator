require 'logger'

module Settlements
  class SettlementGeneratorLogger < Logger
    class << self
      def logger(log_level = 'INFO')
        @logger ||= SettlementGeneratorLogger.new(STDOUT, level: log_level)
      end
    end
  end
end