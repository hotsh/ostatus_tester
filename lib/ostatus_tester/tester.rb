require 'redfinger'

module OStatusTester
  class Tester
    attr_accessor :domain
    attr_accessor :account

    def initialize(domain, account)
      @domain  = domain.dup
      @account = account.dup
    end

    def webfinger_domain
      @account[/@(.*)$/, 1]
    end

    def format_output(str)
    end

    def test_function(p)
      if p
        puts "Pass"
      else
        puts "Fail"
      end
    end

    def test_webfinger
      puts "Testing #{webfinger_domain} for Webfinger Compliance for OStatus..."

      test_function test_webfinger_hostmeta_availability
      test_function test_webfinger_xrd_retrieval
    end

    def test_webfinger_hostmeta_availability
      print " -- Testing hostmeta retrieval... "
      begin
        acct = Redfinger.finger(@account)
        true
      rescue Redfinger::ResourceNotFound => e
        # This happens when the host-meta is explicitly not found
        e.message != "Unable to find the host XRD file."
      rescue Exception => e
        # Redfinger only passes the 404 exception when the xrd cannot be found
        # Which means the host-meta was found
        e.message.match /404/
      end
    end

    def test_webfinger_xrd_retrieval
    end

    def test_xrd_discovery_via_http_header
    end

    def test_profile_url_available_in_xrd
    end

    def test_profile_discovery_via_http_header
    end

    def test_profile_discovery_via_html
    end

    def test
      test_webfinger
    end
  end
end
