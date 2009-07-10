require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'
require 'ruby-debug'

class Enemy
  include DataMapper::Resource
  
  property :id,         String, :key => true
  property :name,       String, :key => true
  property :age,        Integer
  property :wealth,     Float
  property :birthday,   Date
  property :created_at, DateTime
  
  belongs_to :network
end

describe 'with nils records saved and retreived' do
  before(:each) do
    @person_attrs = { :id => "person-#{Time.now.to_f.to_s}", :name => 'Jeremy Boles', :age  => 25, :wealth => 25.00, :birthday => Date.today }
    @jeremy   = Enemy.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Jeremy Boles", :age => 25))
    @danielle = Enemy.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => nil, :age => 26, :birthday => nil))
    sleep(0.4) #or the get calls might not have these created yet
  end
  
  after(:each) do
    @jeremy.destroy
    @danielle.destroy
    sleep(0.4) #or might not be destroyed by the next test
  end
  
  it 'should get all records' do
    Enemy.all.length.should == 2
  end
  
  it 'should get retrieve nil values' do
    people = Enemy.all(:age => 26)
    people.length.should == 1
    people[0].name.should == nil
    people[0].birthday.should == nil
  end

  #fails but might work if we switch to using the helena lib
  it 'should find based on nil values'

end
