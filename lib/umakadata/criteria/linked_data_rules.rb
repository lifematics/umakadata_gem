require 'umakadata/http_helper'
require 'umakadata/sparql_helper'
require 'umakadata/logging/log'

module Umakadata
  module Criteria
    module LinkedDataRules

      include Umakadata::HTTPHelper

      REGEXP = /<title>(.*)<\/title>/

      def prepare(uri)
        @client = SPARQL::Client.new(uri, {'read_timeout': 5 * 60}) if @uri == uri && @client == nil
        @uri = uri
      end

      def uri_subject?(uri, logger: nil)
        sparql_query = <<-'SPARQL'
SELECT
  *
WHERE {
GRAPH ?g { ?s ?p ?o } .
  filter (!isURI(?s) && !isBLANK(?s) && ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
SPARQL

        [:post, :get].each do |method|
          log = Umakadata::Logging::Log.new
          logger.push log unless logger.nil?
          results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
          if results != nil
            if results.count == 0
              log.result = "#{method.to_s.capitalize}: 0 non-URI subjects is found"
              logger.result = 'URIs are used as names' unless logger.nil?
              return true
            else
              log.result = "#{method.to_s.capitalize}: #{results.count} non-URI subjects is found"
              logger.result = 'URIs are not used as names' unless logger.nil?
              return false
            end
          else
            log.result = "#{method.to_s.capitalize}: An error occured in searching"
          end
        end
        logger.result = '' unless logger.nil?
        false
      end

      def http_subject?(uri, logger: nil)
        sparql_query = <<-'SPARQL'
SELECT
  *
WHERE {
  GRAPH ?g { ?s ?p ?o } .
  filter (!regex(?s, "http://", "i") && !isBLANK(?s) && ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
SPARQL

        [:post, :get].each do |method|
          log = Umakadata::Logging::Log.new
          logger.push log unless logger.nil?
          results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
          if results != nil
            if results.count == 0
              log.result = "#{method.to_s.capitalize}: 0 non-HTTP-URI subjects is found"
              logger.result = "HTTP URIs are used" unless logger.nil?
              return true
            else
              log.result = "#{method.to_s.capitalize}: #{results.count} non-HTTP-URI subjects is found"
              logger.result = "HTTP URIs are not used" unless logger.nil?
              return false
            end
          else
            log.result = "#{method.to_s.capitalize}: An error occured in searching"
          end
        end
        logger.result = '' unless logger.nil?

        false
      end

      def uri_provides_info?(uri, logger: nil)
        uri = self.get_subject_randomly(uri, logger: logger)
        if uri == nil
          logger.result = 'The endpoint does not find any URI' unless logger.nil?
          return false
        end

        log = Umakadata::Logging::Log.new
        logger.push log unless logger.nil?
        begin
          response = http_get_recursive(URI(uri), {logger: log}, 10)
        rescue
          log.result = "Invalid URI: #{uri}"
          logger.result = 'An error occurred in searching' unless logger.nil?
          return false
        end

        if !response.is_a?(Net::HTTPSuccess)
          log.result = "#{uri} does not return 200 HTTP response"
          logger.result = "#{uri} does not provide useful information" unless logger.nil?
          return false
        end

        if response.body.empty?
          log.result = "#{uri} returns empty data"
          logger.result = "#{uri} does not provide useful information" unless logger.nil?
          return false
        end

        log.result = "#{uri} returns any data"
        logger.result = "#{uri} provides useful information" unless logger.nil?
        true
      end

      def get_subject_randomly(uri, logger: nil)
        sparql_query = <<-'SPARQL'
SELECT
  ?s
WHERE {
  GRAPH ?g { ?s ?p ?o } .
  filter (isURI(?s) && ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
OFFSET 100
SPARQL

        [:post, :get].each do |method|
          log = Umakadata::Logging::Log.new
          logger.push log unless logger.nil?
          results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
          if results != nil && results[0] != nil
            log.result = "#{method.to_s.capitalize}: #{results[0][:s]} is found"
            return results[0][:s]
          end
          log.result = "#{method.to_s.capitalize}: a URI is not found"
        end
        nil
      end

      def contains_links?(uri, logger: nil)
        same_as_log = Umakadata::Logging::Log.new
        logger.push same_as_log unless logger.nil?
        same_as = self.contains_same_as?(uri, logger: same_as_log)
        if same_as
          logger.result = "#{uri} includes links to other URIs" unless logger.nil?
          return true
        end

        contains_see_also_log = Umakadata::Logging::Log.new
        logger.push contains_see_also_log unless logger.nil?
        see_also = self.contains_see_also?(uri, logger: contains_see_also_log)
        if see_also
          logger.result = "#{uri} includes links to other URIs" unless logger.nil?
          return true
        end
        logger.result = "#{uri} does not include links to other URIs" unless logger.nil?
        false
      end

      def contains_same_as?(uri, logger: nil)
        sparql_query = <<-'SPARQL'
PREFIX owl:<http://www.w3.org/2002/07/owl#>
SELECT
  *
WHERE {
  GRAPH ?g { ?s owl:sameAs ?o } .
}
LIMIT 1
SPARQL

        [:post, :get].each do |method|
          log = Umakadata::Logging::Log.new
          logger.push log unless logger.nil?
          results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
          if results != nil && results.count > 0
            log.result = "#{method.to_s.capitalize}: #{results.count} owl:sameAs statement is found"
            logger.result = 'The owl:sameAs statement is found' unless logger.nil?
            return true
          end
          log.result = "#{method.to_s.capitalize}: The owl:sameAs statement is not found"
        end

        logger.result = 'The owl:sameAs statement is not found' unless logger.nil?
        false
      end

      def contains_see_also?(uri, logger: nil)
        sparql_query = <<-'SPARQL'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  *
WHERE {
  GRAPH ?g { ?s rdfs:seeAlso ?o } .
}
LIMIT 1
SPARQL

        [:post, :get].each do |method|
          log = Umakadata::Logging::Log.new
          logger.push log unless logger.nil?
          results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
          if results != nil && results.count > 0
            log.result = "#{method.to_s.capitalize}: #{results.count} rdfs:seeAlso statement is found"
            logger.result = 'The rdfs:seeAlso statement is found' unless logger.nil?
            return true
          end
          log.result = "#{method.to_s.capitalize}: The rdfs:seeAlso statement is not find"
        end

        logger.result = 'The rdfs:seeAlso statement is not find' unless logger.nil?
        false
      end

    end
  end
end
