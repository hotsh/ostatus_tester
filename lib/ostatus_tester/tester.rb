require 'redfinger'
require 'nokogiri'
require 'ostatus'
require 'rsa'
require 'base64'

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

    def ostatus_domain
      @domain[/^http[s]?:\/\/(.*)$/, 1]
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
      puts "Testing #{ostatus_domain} for OStatus Compliance..."

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

    def test_salmon_endpoint_in_xrd
      print " -- Testing if xrd contains salmon url... "

      begin
        acct = Redfinger.finger(@account)

        link = acct.links.find do |l|
          l['rel'] == "salmon"
        end

        if link.nil?
          false
        else
          link.href
        end
      rescue
        false
      end
    end

    def test_salmon_replies_endpoint_in_xrd
      print " -- Testing if xrd contains salmon replies url... "

      begin
        acct = Redfinger.finger(@account)

        link = acct.links.find do |l|
          l['rel'] == "http://salmon-protocol.org/ns/salmon-replies"
        end

        if link.nil?
          false
        else
          link.href
        end
      rescue
        false
      end
    end

    def test_salmon_mention_endpoint_in_xrd
      print " -- Testing if xrd contains salmon mention url... "

      begin
        acct = Redfinger.finger(@account)

        link = acct.links.find do |l|
          l['rel'] == "http://salmon-protocol.org/ns/salmon-mention"
        end

        if link.nil?
          false
        else
          link.href
        end
      rescue
        false
      end
    end

    def craft_salmon
      poco = OStatus::PortableContacts.new(:id => "1",
                                           :preferred_username => "testuser")

      author = OStatus::Author.new(:name  => "testuser",
                                   :uri   => "http://www.example.com",
                                   :portable_contacts => poco,
                                   :links => [Atom::Link.new(:rel  => "avatar",
                                                             :type => "image/png",
                                                             :href => "http://www.example.com")])

      entry = OStatus::Entry.new(:title => "Test Entry",
                                 :content => "Test Entry",
                                 :updated => DateTime.now,
                                 :published => DateTime.now,
                                 :activity => OStatus::Activity.new(:object_type => :note),
                                 :author => author,
                                 :id => "1",
                                 :links => [])

      OStatus::Salmon.new entry
    end

    def test_salmon_202_or_4xx_when_salmon_is_posted
      print " -- Testing if the response is 202 or 4xx when salmon notification is posted... "

      begin
        acct = Redfinger.finger(@account)

        link = acct.links.find do |l|
          l['rel'] == "salmon"
        end

        if link.nil?
          return false
        else
          salmon_url = link.href
        end
      rescue
        return false
      end

      keypair = RSA::KeyPair.generate(2048)

      salmon = craft_salmon

      begin
        response = RestClient.post(salmon_url,
                                   salmon.to_xml(keypair),
                                   :content_type => "application/magic-envelope+xml")
      rescue
        return true
      end

      response.code == 202 || (response.code >= 400 && response.code < 500)
    end

    def test_salmon
      puts "Testing #{webfinger_domain} for Salmon Compliance for OStatus..."

      test_function test_salmon_endpoint_in_xrd
      test_function test_salmon_replies_endpoint_in_xrd
      test_function test_salmon_mention_endpoint_in_xrd

      puts "Testing #{ostatus_domain} for Salmon Compliance for OStatus..."

      test_function test_salmon_202_or_4xx_when_salmon_is_posted
    end

    def test
      test_webfinger
      test_ostatus
      test_salmon
    end
  end
end
