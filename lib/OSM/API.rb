# Contains the OSM::API class

require 'net/http'
require 'OSM/objects.rb'
require 'OSM/StreamParser.rb'

module OSM

    class APIError < Exception; end
    class APITooManyObjects < APIError; end
    class APIBadRequest < APIError; end # 400
    class APIUnauthorized < APIError; end # 401
    class APINotFound < APIError; end # 404
    class APIGone < APIError; end # 410
    class APIServerError < APIError; end # 500

    class SingleObjectCallbacks < OSM::Callbacks

        def node(node)
            raise APITooManyObjects unless @result.nil?
            @result = node
        end

        def way(way)
            raise APITooManyObjects unless @result.nil?
            @result = way
        end

        def relation(relation)
            raise APITooManyObjects unless @result.nil?
            @result = relation
        end

        def result
            @result
        end

    end

    # The OSM::API class handles all calls to the OpenStreetMap API.
    #
    # Usage:
    #   @api = OSM::API.new
    #   node = @api.get_node(3437)
    #
    # In most cases you can use the more convenient methods on the OSM::Node, OSM::Way,
    # or OSM::Relation objects.
    #
    class API

        # the default base URI for the API
        DEFAULT_BASE_URI = 'http://www.openstreetmap.org/api/0.5/'

        # Creates a new API object. Without any arguments it uses the default API at
        # DEFAULT_BASE_URI. If you want to use a different API, give the base URI
        # as parameter to this method.
        def initialize(uri=DEFAULT_BASE_URI)
            @base_uri = uri
        end

        # Get an object ('node', 'way', or 'relation') with specified ID from API.
        #
        # call-seq: get_object(type, id) -> OSM::Object
        #
        def get_object(type, id)
            raise ArgumentError.new("type needs to be one of 'node', 'way', and 'relation'") unless type =~ /^(node|way|relation)$/
            raise TypeError.new('id needs to be a positive integer') unless(id.kind_of?(Fixnum) && id > 0)
            response = get("#{type}/#{id}")
            check_response_codes(response)
            parser = OSM::StreamParser.new(:string => response.body, :callbacks => OSM::ObjectListCallbacks.new)
            list = parser.parse
            raise APITooManyObjects if list.size > 1
            list[0]
        end

        # Get a node with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Node
        #
        def get_node(id)
            get_object('node', id)
        end

        # Get a way with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Way
        #
        def get_way(id)
            get_object('way', id)
        end

        # Get a relation with specified ID from API.
        #
        # call-seq: get_node(id) -> OSM::Relation
        #
        def get_relation(id)
            get_object('relation', id)
        end

        # Get all ways using the node with specified ID from API.
        #
        # call-seq: get_ways_using_node(id) -> Array of OSM::Way
        #
        def get_ways_using_node(id)
            api_call(id, "node/#{id}/ways")
        end

        # Get all relations which refer to the object of specified type and with specified ID from API.
        #
        # call-seq: get_relations_referring_to_object(type, id) -> Array of OSM::Relation
        #
        def get_relations_referring_to_object(type, id)
            api_call_with_type(type, id, "#{type}/#{id}/relations")
        end

        # Get all historic versions of an object of specified type and with specified ID from API.
        #
        # call-seq: get_history(type, id) -> Array of OSM::Object
        #
        def get_history(type, id)
            return [] if type == 'relation' # XXX currently broken in API
            api_call_with_type(type, id, "#{type}/#{id}/history")
        end

        private

        def api_call_with_type(type, id, path)
            raise ArgumentError.new("type needs to be one of 'node', 'way', and 'relation'") unless type =~ /^(node|way|relation)$/
            api_call(id, path)
        end

        def api_call(id, path)
            raise TypeError.new('id needs to be a positive integer') unless(id.kind_of?(Fixnum) && id > 0)
            response = get(path)
            check_response_codes(response)
            parser = OSM::StreamParser.new(:string => response.body, :callbacks => OSM::ObjectListCallbacks.new)
            parser.parse
        end

        def get(suffix)
            uri = URI.parse(@base_uri + suffix)
            request = Net::HTTP.new(uri.host, uri.port)
            request.get(uri.path)
        end

        def check_response_codes(response)
            case response.code.to_i
                when 200 then return
                when 404 then raise APINotFound
                when 410 then raise APIGone
                when 500 then raise APIServerError
                else raise APIError
            end
        end

    end

end
