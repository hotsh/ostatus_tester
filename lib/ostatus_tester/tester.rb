require 'redfinger'
require 'nokogiri'

# Workaround for Redfinger hiding template fields
module Redfinger
  class Link
    class << self
      alias_method :old_from_xml, :from_xml
    end

    def self.from_xml(xml_link)
      new_link = Link.old_from_xml(xml_link)
      new_link[:template] = xml_link['template']
      new_link
    end
  end
end

module OStatusTester
  class Tester
    attr_accessor :domain
    attr_accessor :account

    def initialize(domain, account)
      @domain  = domain.dup
      if @domain.match /\/$/
        @domain = @domain[0..-1]
      end
      @account = account.dup
    end

    def webfinger_domain
      @account[/@(.*)$/, 1]
    end

    def format_output(str)
    end

    def test_function(p)
      if not p
        puts "Fail"
      elsif p == true
        puts "Pass"
      else
        puts "Pass (#{p})"
      end
    end

    def test_webfinger
      puts "Testing #{webfinger_domain} for Webfinger Compliance for OStatus..."

      test_function test_webfinger_hostmeta_availability
      test_function test_webfinger_xrd_retrieval
      test_function test_webfinger_xrd_contains_profile_page
      test_function test_webfinger_xrd_contains_feed_uri
      test_function test_webfinger_xrd_contains_subscription_template
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
      print " -- Testing xrd retrieval... "
      begin
        acct = Redfinger.finger(@account)
        true
      rescue
        false
      end
    end

    def test_webfinger_xrd_contains_profile_page
      print " -- Testing if xrd contains profile page... "

      begin
        acct = Redfinger.finger(@account)

        if acct.profile_page.empty?
          false
        else
          acct.profile_page[0].href
        end
      rescue
        false
      end
    end

    def test_webfinger_xrd_contains_feed_uri
      print " -- Testing if xrd contains feed uri... "

      begin
        acct = Redfinger.finger(@account)

      rescue
        false
      end

        link = acct.links.find do |l|
          l['rel'] == "http://schemas.google.com/g/2010#updates-from"
        end

        if link.nil?
          false
        else
          link.href
        end
    end

    def test_webfinger_xrd_contains_subscription_template
      print " -- Testing if xrd contains subscription template... "

      begin
        acct = Redfinger.finger(@account)

        link = acct.links.find do |l|
          l['rel'] == "http://ostatus.org/schema/1.0/subscribe"
        end

        if link.nil?
          false
        else
          link.template
        end
      rescue
        false
      end
    end

    def test_ostatus
      puts "Testing #{webfinger_domain} for OStatus Compliance..."

      test_function test_xrd_discovery_via_http_header
      test_function test_feed_discovery_via_html
    end

    def profile_page_url
      acct = Redfinger.finger(@account)
      acct.profile_page[0].href
    end

    def test_xrd_discovery_via_http_header
      print " -- Testing if xrd can be discovered via a Link in the HTTP header... "
      response = RestClient.get profile_page_url

      if response.headers[:link].match /rel=\"lrdd\"/
        response.headers[:link][/^<(.*?)>/,1]
      else
        false
      end
    end

    def test_feed_discovery_via_html
      print " -- Testing if feed url can be discovered via a link tag in the HTML... "
      response = RestClient.get profile_page_url, {:accept => :html}

      xml = Nokogiri.HTML(response.to_str)
      links = xml.xpath("//link[@rel='alternate'][@type='application/atom+xml']")

      if links.empty?
        false
      else
        links.first.attributes['href']
      end
    end

    def test
      test_webfinger
      test_ostatus
    end
  end
end
