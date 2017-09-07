require 'routemaster/models'
require 'routemaster/mixins/assert'
require 'delegate'

module Routemaster
  module Models
    class ResourceID < SimpleDelegator
      include Mixins::Assert

      UUID_RE = /\A[a-z0-9]{8}(?:-[a-z0-9]{4}){3}-[a-z0-9]{12}\Z/.freeze

      def initialize(value)
        case value
        when Integer
          _assert(value >= 0, 'negative integer')
        when String
          _assert(value =~ UUID_RE, 'not a valid lowercase UUID')
        else
          raise ArgumentError, 'resource IDs must be positive integers or lowercase UUIDs'
        end
        super
      end
    end
  end
end
