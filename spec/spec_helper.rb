require 'pathname'
require Pathname(__FILE__).dirname.parent.expand_path + 'lib/simpledb_adapter'
require 'ruby-debug'

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
  :domain => 'missionaries'
})
