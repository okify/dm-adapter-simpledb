require 'rubygems'
require 'dm-core'
require 'digest/sha1'
require 'dm-aggregates'
require 'right_aws' 

module DataMapper
  module Adapters
    class SimpleDBAdapter < AbstractAdapter

      def create(resources)
        created = 0
        resources.each do |resource|
          item_name = item_name_for_resource(resource)
          sdb_type = simpledb_type(resource.model)
          attributes = resource.attributes.merge(:simpledb_type => sdb_type)
          sdb.put_attributes(domain, item_name, attributes)
          created += 1
        end
        created
      end
      
      def delete(query)
        deleted = 0
        item_name = item_name_for_query(query)
        sdb.delete_attributes(domain, item_name)
        deleted += 1
        raise NotImplementedError.new('Only :eql on delete at the moment') if not_eql_query?(query)
        deleted
      end

      def read_many(query)
        sdb_type = simpledb_type(query.model)
        
        conditions = set_conditions(query, sdb_type)
        order = set_sort_order(query, conditions)
        results = get_results(query, conditions, order)
        
        Collection.new(query) do |collection|
          results.each do |result|
            data = query.fields.map do |property|
              value = result[:attributes][property.field.to_s]
              if value != nil
                if value.size > 1
                  value.map {|v| property.typecast(v) }
                else
                  property.typecast(value[0])
                end
              else
                 property.typecast(nil)
              end
            end
            collection.load(data)
          end
        end
      end
      
      def read_one(query)
        #already has limit defined as 1 return first/only result from collection
        results = read_many(query)
        results.inspect #force the lazy loading to actually load
        results[0]
      end
 
      def update(attributes, query)
        updated = 0
        item_name = item_name_for_query(query)
        attributes = attributes.to_a.map {|a| [a.first.name.to_s, a.last]}.to_hash
        sdb.put_attributes(domain, item_name, attributes, true)
        updated += 1
        raise NotImplementedError.new('Only :eql on delete at the moment') if not_eql_query?(query)
        updated
      end
      
    private

      # Returns the domain for the model
      def domain
        @uri[:domain]
      end

      #sets the conditions for the SDB query
      def set_conditions(query, sdb_type)
        conditions = ["['simpledb_type' = '#{sdb_type}']"]
        if query.conditions.size > 0
          conditions += query.conditions.map do |condition|
            operator = case condition[0]
              when :eql then '='
              when :not then '!='
              when :gt then '>'
              when :gte then '>='
              when :lt then '<'
              when :lte then '<='
              else raise "Invalid query operator: #{operator.inspect}"
            end
            "['#{condition[1].name.to_s}' #{operator} '#{condition[2].to_s}']"
          end
        end
        conditions
      end

      #adds sort information to SDB query
      def set_sort_order(query, conditions)
        if query.order!=nil && query.order.length > 0
          query_object = query.order[0]
          conditions << "['#{query_object.property.name.to_s}'> '']" #anything sorted on must be a condition
          order = "sort '#{query_object.property.name.to_s}' #{query_object.direction==:desc ? 'DESC' : 'ASC'}"
        else
          order = ""
        end
      end
      
      #gets all results or proper number of results depending on the :limit
      def get_results(query, conditions, order)
        results = sdb.query(domain, "#{conditions.compact.join(' intersection ')} #{order}")
        if query.limit!=nil && query.limit <= results[:items].length
          results[:items] = results[:items][0...query.limit]
        else
          sdb_continuation_key = results[:next_token]
          #this means there are more results to retrieve from SDB
          while (sdb_continuation_key!=nil) do
            old_results = results
            results = sdb.query(domain, "#{conditions.compact.join(' intersection ')} #{order}", nil, sdb_continuation_key)
            results[:items] = old_results[:items] + results[:items]
            sdb_continuation_key = results[:next_token]
          end
        end
        #todo use newer SDB batch get attributes
        results = results[:items].map {|d| sdb.get_attributes(domain, d) }
      end
      
      # Creates an item name for a query
      def item_name_for_query(query)
        sdb_type = simpledb_type(query.model)
        
        item_name = "#{sdb_type}+"
        keys = keys_for_model(query.model)
        conditions = query.conditions.sort {|a,b| a[1].name.to_s <=> b[1].name.to_s }
        item_name += conditions.map do |property|
          property[2].to_s
        end.join('-')
        Digest::SHA1.hexdigest(item_name)
      end
      
      # Creates an item name for a resource
      def item_name_for_resource(resource)
        sdb_type = simpledb_type(resource.model)
        
        item_name = "#{sdb_type}+"
        keys = keys_for_model(resource.model)
        item_name += keys.map do |property|
          resource.instance_variable_get(property.instance_variable_name)
        end.join('-')
        
        Digest::SHA1.hexdigest(item_name)
      end
      
      # Returns the keys for model sorted in alphabetical order
      def keys_for_model(model)
        model.key(self.name).sort {|a,b| a.name.to_s <=> b.name.to_s }
      end
      
      def not_eql_query?(query)
        # Curosity check to make sure we are only dealing with a delete
        conditions = query.conditions.map {|c| c[0] }.uniq
        selectors = [ :gt, :gte, :lt, :lte, :not, :like, :in ]
        return (selectors - conditions).size != selectors.size
      end
      
      # Returns an SimpleDB instance to work with
      def sdb
        access_key = @uri[:access_key]
        secret_key = @uri[:secret_key]
        @sdb ||= RightAws::SdbInterface.new(access_key,secret_key)
        @sdb
      end
      
      # Returns a string so we know what type of
      def simpledb_type(model)
        model.storage_name(model.repository.name)
      end

      #integrated from http://github.com/edward/dm-simpledb/tree/master
      module Migration
        # Returns whether the storage_name exists.
        # @param storage_name<String> a String defining the name of a domain
        # @return <Boolean> true if the storage exists
        def storage_exists?(storage_name)
          domains = sdb.list_domains[:domains]
          domains.detect {|d| d == storage_name }!=nil
        end
        
        def create_model_storage(repository, model)
          sdb.create_domain(@uri[:domain])
        end
        
        #On SimpleDB you probably don't want to destroy the whole domain
        #if you are just adding fields it is automatically supported
        #default to non destructive migrate, to destroy run
        #rake db:automigrate destroy=true
        def destroy_model_storage(repository, model)
          if ENV['destroy']!=nil && ENV['destroy']=='true'
            sdb.delete_domain(@uri[:domain])
          end
        end
        
        #TODO look at github panda simpleDB for serials support?
        module SQL
          def supports_serial?
            false
          end
        end
        
        include SQL
        
      end # module Migration
      
      include Migration
      
    end # class SimpleDBAdapter
    
    # Required naming scheme.
    SimpledbAdapter = SimpleDBAdapter
    
  end # module Adapters
end # module DataMapper
