require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

class Professor
  include DataMapper::Resource
  
  property :id,         String, :key => true
  property :name,       String, :key => true
  property :age,        Integer
  property :wealth,     Float
  property :birthday,   Date
  property :created_at, DateTime
  
end

describe 'with multiple records saved' do
  before(:each) do
    @person_attrs = { :id => "person-#{Time.now.to_f.to_s}", :name => 'Jeremy Boles', :age  => 25, :wealth => 25.00, :birthday => Date.today }
    @jeremy   = Professor.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Jeremy Boles", :age => 25))
    @danielle = Professor.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Danille Boles", :age => 26))
    @keegan   = Professor.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Keegan Jones", :age => 20))
    sleep(0.4) #or the get calls might not have these created yet
  end
  
  after(:each) do
    @jeremy.destroy
    @danielle.destroy
    @keegan.destroy
    sleep(0.4) #or might not be destroyed by the next test
  end
  
  it 'should handle DateTime' do
    pending 'Need to figure out how to coerce DateTime'
    time = Time.now
    @jeremy.created_at = time
    @jeremy.save
    sleep(0.2)
    person = Professor.get!(@jeremy.id, @jeremy.name)
    person.created_at.should == time
  end
  
  it 'should handle Date' do
    person = Professor.get!(@jeremy.id, @jeremy.name)
    person.birthday.should == @jeremy.birthday
  end
  
  it 'should match with Data' do
    people = Professor.all(:birthday => Date.today)
    people.length.should == 3
  end

end
