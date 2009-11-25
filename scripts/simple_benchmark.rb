require 'pathname'
require Pathname(__FILE__).dirname.parent.expand_path + 'lib/dm-adapter-simpledb'
require 'ruby-debug'
require 'benchmark'

access_key = ENV['AMAZON_ACCESS_KEY_ID']
secret_key = ENV['AMAZON_SECRET_ACCESS_KEY']

#For those that don't like to mess up their ENV
if access_key==nil && secret_key==nil
  lines = File.readlines(File.join(File.dirname(__FILE__),'..','aws_config'))
  access_key = lines[0].strip
  secret_key = lines[1].strip
end

DataMapper.setup(:default, {
  :adapter => 'simpledb',
  :access_key => access_key,
  :secret_key => secret_key,
  :domain => 'benchmark'
})

class Person
  include DataMapper::Resource
  
  property :id,         String, :key => true
  property :name,       String, :key => true
  property :age,        Integer
  property :wealth,     Float
  property :birthday,   Date
  property :created_at, DateTime
end

@adapter = repository(:default).adapter


def rand_str(length = 10)
  (0...length).map{65.+(rand(25)).chr}.join
end

def clean_up
  #clean up by removing the benchmark storage model
  ENV['destroy']='true'
  @adapter.destroy_model_storage(repository(:default), Person)
  ENV['destroy']='false'
end

#clean_up
#sleep(5)

Person.auto_migrate!
sleep(1)

Benchmark.bm do|b|
  friends = []
  number = 200

  b.report("creating #{number} users") do
    number.times do
      friend_attrs = { :id => "person-#{rand_str}-#{Time.now.to_f.to_s}", :name => "name #{Time.now.to_f.to_s} #{rand_str}", :age  => 25, :wealth => 25.00, :birthday => Date.today }
      friend = Person.create(friend_attrs)
      friends << friend
    end
  end
  
  sleep(5.5) #let everything distribute through SDB
  Person.all(:age => 25) #seems to make sure the first one gets the right amount

  b.report("Finding all users age 25, 100 Times") do
    100.times do
      people = Person.all(:age => 25, :limit => number)
      if people.length!=number
        puts "warning wrong number or users #{people.length}"
        #clean_up
        #raise "wrong amount of peoplefound" 
      end
    end
  end

end

clean_up
sleep(2)

