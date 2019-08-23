require 'umakadata/util/cacheable'
require 'umakadata/util/string'

module Umakadata
  module Criteria
    module Helpers
      module UsefulnessHelper
        include Cacheable
        include StringExt

        # @return [Umakadata::Activity]
        def graphs(**options)
          cache(:graphs, options) do
            if endpoint.graph_keyword_supported?
              endpoint.sparql.select(:g).distinct.graph(:g).where(%i[s p o]).execute.tap do |act|
                act.type = Activity::Type::GRAPHS
                act.comment = if act.result.present?
                                "#{pluralize(act.result.count, 'graph')} found."
                              else
                                'No graphs found.'
                              end
              end
            else
              endpoint.graph_keyword_support
            end
          end
        end

        # @param [Hash{Symbol => Object}] options
        # @option options [String] :graph
        # @return [Umakadata::Activity]
        def classes(**options)
          cache(:classes, options) do
            g = options[:graph]
            buffer = ['PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>']
            buffer << 'SELECT DISTINCT ?c WHERE {'
            buffer << "GRAPH <#{g}> {" if g
            buffer << '{ ?c a rdfs:Class . }'
            buffer << 'UNION { [] a ?c . }'
            buffer << 'UNION { [] rdfs:domain ?c . }'
            buffer << 'UNION { [] rdfs:range ?c . }'
            buffer << 'UNION { ?c rdfs:subClassOf [] . }'
            buffer << 'UNION { [] rdfs:subClassOf ?c . }'
            buffer << '}' if options[:graph]
            buffer << '} LIMIT 100'

            endpoint.sparql.query(buffer.join(' ')).tap do |act|
              act.type = Activity::Type::CLASSES
              act.comment = if act.result.present?
                              "#{pluralize(act.result.count, 'class')} found"
                            else
                              'No classes found'
                            end
              act.comment << " on #{g ? "graph <#{g}>" : 'default graph'}."
            end
          end
        end

        # @param [Hash{Symbol => Object}] options
        # @option options [String] :graph
        # @return [Umakadata::Activity]
        def classes_having_instance(**options)
          cache(:classes_having_instance, options) do
            g = options[:graph]
            endpoint
              .sparql
              .select(:c)
              .distinct
              .tap { |x| x.graph(g) if g }
              .where([::RDF::BlankNode.new, ::RDF::RDFV.type, :c])
              .execute
              .tap do |act|
              act.type = Activity::Type::CLASSES_HAVING_INSTANCE
              act.comment = if act.result.present?
                              "#{pluralize(act.result.count, 'class')} having instances found"
                            else
                              'No instances found'
                            end
              act.comment << " on #{g ? "graph <#{g}>" : 'default graph'}."
            end
          end
        end

        # @param [Array<String, #to_s>] classes
        # @param [Hash{Symbol => Object}] options
        # @option options [String] :graph
        # @return [Umakadata::Activity]
        def labels_of_classes(classes, **options)
          if Array(classes).empty?
            return Activity.new do |act|
              act.result = []
              act.type = Activity::Type::LABELS_OF_CLASSES
              act.comment = 'Classes empty.'
            end
          end

          g = options[:graph]
          endpoint
            .sparql
            .select(:c, :label)
            .distinct
            .tap { |x| x.graph(g) if g }
            .where([:c, ::RDF::Vocab::RDFS.label, :label])
            .values(:c, *Array(classes))
            .execute
            .tap do |act|
            act.type = Activity::Type::LABELS_OF_CLASSES
            act.comment = if act.result.present?
                            "#{pluralize(act.result.count, 'label')} of classes found"
                          else
                            'No instances found'
                          end
            act.comment << " on #{g ? "graph <#{g}>" : 'default graph'}."
          end
        end

        # @param [Hash{Symbol => Object}] options
        # @option options [String] :graph
        # @return [Umakadata::Activity]
        def properties(**options)
          cache(:properties, options) do
            g = options[:graph]
            endpoint
              .sparql
              .select(:p)
              .distinct
              .tap { |x| x.graph(g) if g }
              .where(%i[s p o])
              .execute
              .tap do |act|
              act.type = Activity::Type::PROPERTIES
              act.comment = if act.result.present?
                              "#{pluralize(act.result.count, 'property')} found"
                            else
                              'No properties found'
                            end
              act.comment << " on #{g ? "graph <#{g}>" : 'default graph'}."
            end
          end
        end

        BIND_FOR_EXTRACTING_PREFIX = 'IF(CONTAINS(STR(?p), "#"), REPLACE(STR(?p), "#[^#]*$", "#"), '\
                                     'REPLACE(STR(?p), "/[^/]*$", "/")) AS ?prefix'.freeze

        # @param [Hash{Symbol => Object}] options
        # @option options [String] :graph
        # @return [Umakadata::Activity]
        def vocabulary_prefixes(**options)
          cache(:vocabulary_prefixes, options) do
            g = options[:graph]
            endpoint
              .sparql
              .select(:prefix)
              .distinct
              .where(endpoint.sparql.select(:p).distinct.tap { |x| x.graph(g) if g }.where(%i[s p o]))
              .tap { |x| (x.options[:filters] ||= []) << ::SPARQL::Client::Query::Bind.new(BIND_FOR_EXTRACTING_PREFIX) }
              .execute
              .tap do |act|
              act.type = Activity::Type::VOCABULARY_PREFIXES
              act.comment = if act.result.present?
                              "#{pluralize(act.result.count, 'candidate')} for vocabulary prefix found"
                            else
                              'No candidates for vocabulary prefix found'
                            end
              act.comment << " on #{g ? "graph <#{g}>" : 'default graph'}."
            end
          end
        end

        # @return [Umakadata::Activity]
        def number_of_statements(**options)
          cache(:number_of_statements, options) do
            endpoint
              .sparql
              .select(count: { '*' => :count })
              .tap { |x| x.graph(:g) if options[:graph] }
              .where(%i[s p o])
              .execute
              .tap do |act|
              act.type = Activity::Type::NUMBER_OF_STATEMENTS
              act.comment = if act.result.is_a?(Array) && (c = act.result.map { |r| r.bindings[:count] }.first)
                              "#{pluralize(c, 'statement')} in the dataset."
                            else
                              'Failed to count the number of statements.'
                            end
            end
          end
        end
      end
    end
  end
end
