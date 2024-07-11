module PaperTrail
  module Serializers
    module JSON
      extend self

      def load(object)
        object.is_a?(String) ? ActiveSupport::JSON.decode(object) : object
      end
    end
  end
end
