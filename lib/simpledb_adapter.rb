require 'rubygems'
require 'dm-core'
require 'digest/sha1'
require 'dm-aggregates'
require 'right_aws' 

module DataMapper
  module Adapters
    class SimpleDBAdapter < AbstractAdapter

      def initialize(name, opts = {})
        super                                      

        @opts = opts
      end

      def create(resources)
        created = 0
        time = Benchmark.realtime do 
          resources.each do |resource|
            item_name = item_name_for_resource(resource)
            sdb_type = simpledb_type(resource.model)
            attributes = resource.attributes.merge(:simpledb_type => sdb_type)
            attributes.reject!{|key,value| value.nil? || value == '' || value == []}
            sdb.put_attributes(domain, item_name, attributes)
            created += 1
          end
        end; DataMapper.logger.debug(format_log_entry("(#{created}) INSERT #{resources.inspect}", time))
        created
      end
      
      def delete(query)
        deleted = 0
        time = Benchmark.realtime do
          item_name = item_name_for_query(query)
          sdb.delete_attributes(domain, item_name)
          deleted += 1
          raise NotImplementedError.new('Only :eql on delete at the moment') if not_eql_query?(query)
        end; DataMapper.logger.debug(format_log_entry("(#{deleted}) DELETE #{query.conditions.inspect}", time))
        deleted
      end

      def read_many(query)
        sdb_type = simpledb_type(query.model)
        
        conditions, order = set_conditions_and_sort_order(query, sdb_type)
        results = get_results(query, conditions, order)

        Collection.new(query) do |collection|
          results.each do |result|
            data = query.fields.map do |property|
              value = result.values[0][property.field.to_s]
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
        time = Benchmark.realtime do
          item_name = item_name_for_query(query)
          attributes = attributes.to_a.map {|a| [a.first.name.to_s, a.last]}.to_hash
          sdb.put_attributes(domain, item_name, attributes, true)
          updated += 1
          raise NotImplementedError.new('Only :eql on update at the moment') if not_eql_query?(query)
        end; DataMapper.logger.debug(format_log_entry("UPDATE #{query.conditions.inspect} (#{updated} times)", time))
        updated
      end
      
      def query(query_call, query_limit = 999999999)
        select(query_call, query_limit).collect{|x| x.values[0]}
      end
      
      def aggregate(query)
        raise ArgumentError.new("Only count is supported") unless (query.fields.first.operator == :count)
        sdb_type = simpledb_type(query.model)
        conditions, order = set_conditions_and_sort_order(query, sdb_type)

        query_call = "SELECT count(*) FROM #{domain} "
        query_call << "WHERE #{conditions.compact.join(' AND ')}" if conditions.length > 0
        results = nil
        time = Benchmark.realtime do
          results = sdb.select(query_call)
        end; DataMapper.logger.debug(format_log_entry(query_call, time))
        [results[:items][0].values.first["Count"].first.to_i]
      end
      
    private

      # Returns the domain for the model
      def domain
        @uri[:domain]
      end

      #sets the conditions and order for the SDB query
      def set_conditions_and_sort_order(query, sdb_type)
        conditions = ["simpledb_type = '#{sdb_type}'"]
        # look for query.order.first and insure in conditions
        # raise if order if greater than 1

        if query.order && query.order.length > 0
          query_object = query.order[0]
          #anything sorted on must be a condition for SDB
          conditions << "#{query_object.property.name} IS NOT NULL" 
          order = "ORDER BY #{query_object.property.name} #{query_object.direction}"
        else
          order = ""
        end

        query.conditions.each do |operator, attribute, value|
          operator = case operator
                     when :eql
                        if value.nil?
                          conditions << "#{attribute.name} IS NULL"
                          next
                        else
                          '='
                        end
                     when :not
                       if value.nil?
                         conditions << "#{attribute.name} IS NOT NULL"
                         next
                       else
                         '!='
                       end
                     when :gt then '>'
                     when :gte then '>='
                     when :lt then '<'
                     when :lte then '<='
                     when :like then 'like'
                     when :in 
                       values = value.collect{|v| "'#{v}'"}.join(',')
                       values = "'__NULL__'" if values.empty?                       
                       conditions << "#{attribute.name} IN (#{values})"
                       next
                     else raise "Invalid query operator: #{operator.inspect}" 
                     end
          conditions << "#{attribute.name} #{operator} '#{value}'"
        end
        [conditions,order]
      end
      
      def select(query_call, query_limit)
        items = []
        time = Benchmark.realtime do
          sdb_continuation_key = nil
          while (results = sdb.select(query_call, sdb_continuation_key)) do
            sdb_continuation_key = results[:next_token]
            items += results[:items]
            break if items.length > query_limit
            break if sdb_continuation_key.nil?
          end
        end; DataMapper.logger.debug(format_log_entry(query_call, time))
        items[0...query_limit]
      end
      
      #gets all results or proper number of results depending on the :limit
      def get_results(query, conditions, order)
        query_call = "SELECT * FROM #{domain} "
        query_call << "WHERE #{conditions.compact.join(' AND ')}" if conditions.length > 0
        query_call << " #{order}"
        if query.limit!=nil
          query_limit = query.limit
          query_call << " LIMIT #{query.limit}" 
        else
          #on large items force the max limit
          query_limit = 999999999 #TODO hack for query.limit being nil
          #query_call << " limit 2500" #this doesn't work with continuation keys as it halts at the limit passed not just a limit per query.
        end
        select(query_call, query_limit)
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
        @sdb ||= RightAws::SdbInterface.new(access_key,secret_key,@opts)
        @sdb
      end
      
      # Returns a string so we know what type of
      def simpledb_type(model)
        model.storage_name(model.repository.name)
      end

      def format_log_entry(query, ms = 0)
        'SDB (%.1fs)  %s' % [ms, query.squeeze(' ')]
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
