require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'
require Pathname(__FILE__).dirname.expand_path + '../lib/sdb_array'

describe 'with multiple records saved' do
  
  class Hobbyist
    include DataMapper::Resource
    property :name,       String, :key => true
    property :hobbies,     SdbArray
  end
  
  before(:all) do
    @jeremy   = Hobbyist.create(:name => "Jeremy Boles",  :hobbies => ["biking", "diving", "chess"])
    @danielle = Hobbyist.create(:name => "Danille Boles", :hobbies => ["swimming", "diving"])
    @keegan   = Hobbyist.create(:name => "Keegan Jones",  :hobbies => ["painting"])
    sleep(0.4)
  end
  
  after(:all) do
    @jeremy.destroy
    @danielle.destroy
    @keegan.destroy
    sleep(0.4)
  end
  
  it 'should store hobbies as array' do
    person = Hobbyist.first(:name => 'Jeremy Boles')
    person.hobbies.sort.should == ["biking", "diving", "chess"].sort
  end
  
  it 'should find all records with diving hobby' do
    people = Hobbyist.all(:hobbies => 'diving')
    people.should     include(@jeremy)
    people.should     include(@danielle)
    people.should_not include(@keegan)
  end
  
  it 'should find all records with painting hobby' do
    people = Hobbyist.all(:hobbies => 'painting')
    people.should_not include(@jeremy)
    people.should_not include(@danielle)
    people.should     include(@keegan)
  end
  
  it "should find all records with like operator" do
    people = Hobbyist.all(:hobbies.like => 'pa%')
    people.should_not include(@jeremy)
    people.should_not include(@danielle)
    people.should     include(@keegan)
  end

end