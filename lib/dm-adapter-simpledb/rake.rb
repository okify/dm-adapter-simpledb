namespace :simpledb do
  desc "Migrate records to be compatable with current DM/SimpleDB adapter"
  task :migrate, :domain do |t, args|
    raise "THIS IS A WORK IN PROGRESS AND WILL DESTROY YOUR DATA"
    require 'progressbar'
    require 'right_aws'
    require 'dm-adapter-simpledb/record'

    puts "Initializing connection..."
    domain = args.domain
    sdb = RightAws::SdbInterface.new
    puts "Counting records..."
    num_legacy_records = 0
    query = "select count(*) from #{domain} where (simpledb_type is not null) and (__dm_metadata is null)"
    next_token = nil
    while(results = sdb.select(query, next_token)) do
      next_token = results[:next_token]
      count = results[:items].first["Domain"]["Count"].first.to_i
      num_legacy_records += count
      break if next_token.nil?
    end
    puts "Found #{num_legacy_records} to migrate"

    pbar = ProgressBar.new("migrate", num_legacy_records)
    query = "select * from #{domain} where (simpledb_type is not null) and (__dm_metadata is null)"
    while(results = sdb.select(query, next_token)) do
      next_token = results[:next_token]
      items = results[:items]
      items.each do |item|
        legacy_record = DmAdapterSimpledb::Record.from_simpledb_hash(item)
        new_record    = legacy_record.migrate
        updates       = new_record.writable_attributes
        deletes       = new_record.deletable_attributes
        sdb.put_attributes(domain, new_record.item_name, updates)
        sdb.delete_attributes(domain, new_record.item_name, deletes)
        pbar.inc
      end
      break if next_token.nil?
    end
    pbar.finish

  end
end
