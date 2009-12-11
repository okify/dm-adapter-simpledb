module DataMapper
  module Adapters
    class SimpleDBAdapter < AbstractAdapter
      include DmAdapterSimpledb::Utils

      attr_reader :sdb_options

      # For testing purposes ONLY. Seriously, don't enable this for production
      # code.
      attr_accessor :consistency_policy

      def initialize(name, normalised_options)
        super
        @sdb_options = {}
        @sdb_options[:access_key] = options.fetch(:access_key) { 
          options[:user] 
        }
        @sdb_options[:secret_key] = options.fetch(:secret_key) { 
          options[:password] 
        }
        @sdb_options[:logger] = options.fetch(:logger) { DataMapper.logger }
        @sdb_options[:server] = options.fetch(:host) { 'sdb.amazonaws.com' }
        @sdb_options[:port]   = options[:port] || 443 # port may be set but nil
        @sdb_options[:domain] = options.fetch(:domain) { 
          options[:path].to_s.gsub(%r{(^/+)|(/+$)},"") # remove slashes
        }
        # We do not expect to be saving any nils in future, because now we
        # represent null values by removing the attributes. The representation
        # here is chosen on the basis of it being unlikely to match any strings
        # found in real-world records, as well as being eye-catching in case any
        # nils DO manage to sneak in. It would be preferable if we could disable
        # RightAWS's nil-token replacement altogether, but that does not appear
        # to be an option.
        @sdb_options[:nil_representation] = "<[<[<NIL>]>]>"
        @consistency_policy = 
          normalised_options.fetch(:wait_for_consistency) { false }
        @sdb = options.fetch(:sdb_interface) { nil }
      end

      def create(resources)
        created = 0
        domains = []
        time = Benchmark.realtime do
          resources.each do |resource|
            domain = resource.model.storage_name
            domains << domain
            uuid = UUIDTools::UUID.timestamp_create
            initialize_serial(resource, uuid.to_i)

            record     = DmAdapterSimpledb::Record.from_resource(resource)
            attributes = record.writable_attributes
            item_name  = record.item_name
            sdb.put_attributes(domain, item_name, attributes)
            created += 1
          end
        end
        DataMapper.logger.debug(format_log_entry("(#{created}) INSERT #{resources.inspect}", time))
        domains.uniq.each {|d| modified! d} unless domains.empty?
        created
      end
      
      def delete(collection)
        deleted = 0
        domains = []
        time = Benchmark.realtime do
          collection.each do |resource|
            domain = resource.model.storage_name
            domains << domain
            record = DmAdapterSimpledb::Record.from_resource(resource)
            item_name = record.item_name
            sdb.delete_attributes(domain, item_name)
            deleted += 1
          end
          raise NotImplementedError.new('Only :eql on delete at the moment') if not_eql_query?(collection.query)
        end; DataMapper.logger.debug(format_log_entry("(#{deleted}) DELETE #{collection.query.conditions.inspect}", time))
        domains.uniq.each {|d| modified! d} unless domains.empty?
        deleted
      end

      def read(query)
        maybe_wait_for_consistency query.model.storage_name
        table = DmAdapterSimpledb::Table.new(query.model)
        conditions, order, unsupported_conditions = 
          set_conditions_and_sort_order(query, table.simpledb_type)
        results = get_results(query, conditions, order)
        records = results.map{|result| 
          DmAdapterSimpledb::Record.from_simpledb_hash(result)
        }

        proto_resources = records.map{|record|
          record.to_resource_hash(query.fields)
        }
        query.conditions.operands.reject!{ |op|
          !unsupported_conditions.include?(op)
        }
        records = query.filter_records(proto_resources)

        records
      end
      
      def update(attributes, collection)
        updated = 0
        domains = []
        time = Benchmark.realtime do
          collection.each do |resource|
            domain = resource.model.storage_name
            domains << domain
            updated_resource = resource.dup
            updated_resource.attributes = attributes
            record = DmAdapterSimpledb::Record.from_resource(updated_resource)
            attrs_to_update = record.writable_attributes
            attrs_to_delete = record.deletable_attributes
            item_name       = record.item_name
            unless attrs_to_update.empty?
              sdb.put_attributes(domain, item_name, attrs_to_update, :replace)
            end
            unless attrs_to_delete.empty?
              sdb.delete_attributes(domain, item_name, attrs_to_delete)
            end
            updated += 1
          end
          raise NotImplementedError.new('Only :eql on delete at the moment') if not_eql_query?(collection.query)
        end
        DataMapper.logger.debug(format_log_entry("UPDATE #{collection.query.conditions.inspect} (#{updated} times)", time))
        domains.uniq.each {|d| modified! d} unless domains.empty?
        updated
      end
      
      def query(query_call, query_limit = 999999999)
        select(query_call, query_limit).collect{|x| x.values[0]}
      end
      
      def aggregate(query)
        raise ArgumentError.new("Only count is supported") unless (query.fields.first.operator == :count)
        table    = DmAdapterSimpledb::Table.new(query.model)
        sdb_type = table.simpledb_type
        conditions, order, unsupported_conditions = set_conditions_and_sort_order(query, sdb_type)
        domain = query.model.storage_name

        query_call = "SELECT count(*) FROM #{domain} "
        query_call << "WHERE #{conditions.compact.join(' AND ')}" if conditions.length > 0
        results = nil
        time = Benchmark.realtime do
          results = sdb.select(query_call)
        end; DataMapper.logger.debug(format_log_entry(query_call, time))
        [results[:items][0].values.first["Count"].first.to_i]
      end

      # For testing purposes only.
      def wait_for_consistency(domain)
        return unless @current_consistency_token
        token = :none
        begin
          results = sdb.get_attributes(domain, '__dm_consistency_token', '__dm_consistency_token')
          tokens  = results[:attributes]['__dm_consistency_token']
        end until tokens.include?(@current_consistency_token)
      end

    private
      # Returns the domain for the model
      def foo_domain
        @sdb_options[:domain]
      end

      #sets the conditions and order for the SDB query
      def set_conditions_and_sort_order(query, sdb_type)
        unsupported_conditions = []
        conditions = ["simpledb_type = '#{sdb_type}'"]
        # look for query.order.first and insure in conditions
        # raise if order if greater than 1

        if query.order && query.order.length > 0
          query_object = query.order[0]
          #anything sorted on must be a condition for SDB
          conditions << "#{query_object.target.name} IS NOT NULL" 
          order = "ORDER BY #{query_object.target.name} #{query_object.operator}"
        else
          order = ""
        end
        query.conditions.each do |op|
          case op.slug
          when :regexp
            unsupported_conditions << op
          when :eql
            conditions << if op.value.nil?
              "#{op.subject.name} IS NULL"
            else
              "#{op.subject.name} = '#{op.value}'"
            end
          when :not then
            comp = op.operands.first
            if comp.slug == :like
              conditions << "#{comp.subject.name} not like '#{comp.value}'"
              next
            end
            case comp.value
            when Range, Set, Array, Regexp
              unsupported_conditions << op
            when nil
              conditions << "#{comp.subject.name} IS NOT NULL"
            else
              conditions << "#{comp.subject.name} != '#{comp.value}'"
            end
          when :gt then conditions << "#{op.subject.name} > '#{op.value}'"
          when :gte then conditions << "#{op.subject.name} >= '#{op.value}'"
          when :lt then conditions << "#{op.subject.name} < '#{op.value}'"
          when :lte then conditions << "#{op.subject.name} <= '#{op.value}'"
          when :like then conditions << "#{op.subject.name} like '#{op.value}'"
          when :in
            case op.value
            when Array, Set
              values = op.value.collect{|v| "'#{v}'"}.join(',')
              values = "'__NULL__'" if values.empty?                       
              conditions << "#{op.subject.name} IN (#{values})"
            when Range
              if op.value.exclude_end?
                unsupported_conditions << op
              else
                conditions << "#{op.subject.name} between '#{op.value.first}' and '#{op.value.last}'"
              end
            else
              raise ArgumentError, "Unsupported inclusion op: #{op.value.inspect}"
            end
          else raise "Invalid query op: #{op.inspect}"
          end
        end
        [conditions,order,unsupported_conditions]
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
        domain = query.model.storage_name
        fields_to_request = query.fields.map{|f| f.field}
        fields_to_request << DmAdapterSimpledb::Record::METADATA_KEY
        output_list = fields_to_request.join(', ')
        query_call = "SELECT #{output_list} FROM #{domain} "
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
        records = select(query_call, query_limit)
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
      
      def not_eql_query?(query)
        # Curosity check to make sure we are only dealing with a delete
        conditions = query.conditions.map {|c| c.slug }.uniq
        selectors = [ :gt, :gte, :lt, :lte, :not, :like, :in ]
        return (selectors - conditions).size != selectors.size
      end
      
      # Returns an SimpleDB instance to work with
      def sdb
        access_key = @sdb_options[:access_key]
        secret_key = @sdb_options[:secret_key]
        @sdb ||= RightAws::SdbInterface.new(access_key,secret_key,@sdb_options)
        @sdb
      end
      
      def format_log_entry(query, ms = 0)
        'SDB (%.1fs)  %s' % [ms, query.squeeze(' ')]
      end

      def update_consistency_token(domain)
        @current_consistency_token = UUIDTools::UUID.timestamp_create.to_s
        sdb.put_attributes(
          domain, 
          '__dm_consistency_token', 
          {'__dm_consistency_token' => [@current_consistency_token]})
      end

      def maybe_wait_for_consistency(domain)
        if consistency_policy == :automatic && @current_consistency_token
          wait_for_consistency domain
        end
      end

      # SimpleDB supports "eventual consistency", which mean your data will be
      # there... eventually. Obviously this can make tests a little flaky. One
      # option is to just wait a fixed amount of time after every write, but
      # this can quickly add up to a lot of waiting. The strategy implemented
      # here is based on the theory that while consistency is only eventual,
      # chances are writes will at least be linear. That is, once the results of
      # write #2 show up we can probably assume that the results of write #1 are
      # in as well.
      #
      # When a consistency policy is enabled, the adapter writes a new unique
      # "consistency token" to the database after every write (i.e. every
      # create, update, or delete). If the policy is :manual, it only writes the
      # consistency token. If the policy is :automatic, writes will not return
      # until the token has been successfully read back.
      #
      # When waiting for the consistency token to show up, we use progressively
      # longer timeouts until finally giving up and raising an exception.
      def modified!(domain)
        case @consistency_policy
        when :manual, :automatic then
          update_consistency_token domain
        when false then
          # do nothing
        else
          raise "Invalid :wait_for_consistency option: #{@consistency_policy.inspect}"
        end
      end

    end # class SimpleDBAdapter

    
    # Required naming scheme.
    SimpledbAdapter = SimpleDBAdapter

    const_added(:SimpledbAdapter)

  end # module Adapters


end # module DataMapper

