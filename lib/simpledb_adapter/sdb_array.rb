module DataMapper
  module Types
    class SdbArray < DataMapper::Type
      primitive Text

      def self.load(value, property)
        value
      end

      def self.dump(value, property)
        value
      end

      def self.typecast(value, property)
        value
      end
    end 
  end
end
