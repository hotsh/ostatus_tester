require 'optparse'

require_relative '../ostatus_tester/tester'

module OStatusTester
  class CLI
    BANNER = <<-USAGE
    Usage:
      ostatus_tester DOMAIN ACCOUNT

    Example:
      ostatus_tester http://www.domain.com username@example.com
    USAGE

    class << self
      def parse_options
        @opts = OptionParser.new do |opts|
          opts.banner = BANNER.gsub(/^    /, '')

          opts.separator ''
          opts.separator 'Options:'

          opts.on('-h', '--help', 'Display this help') do
            puts opts
            exit
          end
        end

        @opts.parse!
      end

      def CLI.run
        begin
          parse_options
        rescue OptionParser::InvalidOption => e
          warn e
          exit -1
        end

        def fail
          puts @opts
          exit -1
        end

        if ARGV.empty? || ARGV.length != 2
          fail
        end

        tester = OStatusTester::Tester.new(ARGV[0], ARGV[1])
        tester.test
      end
    end
  end
end
