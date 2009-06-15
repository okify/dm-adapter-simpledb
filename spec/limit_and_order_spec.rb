require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

class Hero
  include DataMapper::Resource
  
  property :id,         String, :key => true
  property :name,       String, :key => true
  property :age,        Integer
  property :wealth,     Float
  property :birthday,   Date
  property :created_at, DateTime
  
  belongs_to :company
end

describe 'with multiple records saved' do
  before(:each) do
    @person_attrs = { :id => "person-#{Time.now.to_f.to_s}", :name => 'Jeremy Boles', :age  => 25, :wealth => 25.00, :birthday => Date.today }
    @jeremy   = Hero.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Jeremy Boles", :age => 25))
    @danielle = Hero.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Danille Boles", :age => 26))
    @keegan   = Hero.create(@person_attrs.merge(:id => Time.now.to_f.to_s, :name => "Keegan Jones", :age => 20, :wealth => 15.00))
    sleep(0.4) #or the get calls might not have these created yet
  end
  
  after(:each) do
    @jeremy.destroy
    @danielle.destroy
    @keegan.destroy
    sleep(0.4) #or might not be destroyed by the next test
  end
  
  it 'should handle limit one case' do
    persons = Hero.all(:limit => 1)
    persons.length.should ==1
  end

  it 'should handle max item limit case' do
    persons = Hero.all(:limit => 3)
    persons.length.should ==3
  end

  it 'should handle max item if limit is large case' do
    persons = Hero.all(:limit => 150)
    persons.length.should ==3
  end

  #it would be really slow to create over 100 entires to test this until we have batch creation
  it 'should handle limits over the default SDB 100 results limit'

  #it would be really slow to create over 100 entires to test this until we have batch creation
  it 'should get all results over the default SDB 100 results limit'

  it 'should handle ordering asc results with a limit' do
    persons = Hero.all(:order => [:age.asc], :limit => 2)
    persons.inspect #can't access via array until loaded? Weird
    persons.length.should ==2
    persons[0].should == @keegan
    persons[1].should == @jeremy
  end

  it 'should handle ordering asc results' do
    persons = Hero.all(:order => [:age.asc])
    persons.inspect #can't access via array until loaded? Weird
    persons[0].should == @keegan
    persons[1].should == @jeremy
    persons[2].should == @danielle
  end
  
  it 'should handle ordering desc results' do
    persons = Hero.all(:order => [:age.desc])
    persons.inspect #can't access via array until loaded? Weird
    persons[0].should == @danielle
    persons[1].should == @jeremy
    persons[2].should == @keegan
  end

  it 'should handle ordering results with multiple conditionss' do
    persons = Hero.all(:age.gt => 20, :wealth.gt => 20, :order => [:age.desc])
    persons.inspect #can't access via array until loaded? Weird
    persons.length.should ==2
    persons[0].should == @danielle
    persons[1].should == @jeremy
  end

  it 'should handle ordering results with ordered by conditions' do
    persons = Hero.all(:age.gt => 20, :order => [:age.desc])
    persons.inspect #can't access via array until loaded? Weird
    persons.length.should ==2
    persons[0].should == @danielle
    persons[1].should == @jeremy
  end

  it 'should handle ordering results with unorder by conditions' do
    persons = Hero.all(:wealth.gt => 20.00, :order => [:age.desc])
    persons.inspect #can't access via array until loaded? Weird
    persons.length.should ==2
    persons[0].should == @danielle
    persons[1].should == @jeremy
  end

end
