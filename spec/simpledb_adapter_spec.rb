require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

class Friend
  include DataMapper::Resource
  
  property :id,         String, :key => true
  property :name,       String, :key => true
  property :age,        Integer
  property :wealth,     Float
  property :birthday,   Date
  property :created_at, DateTime
  
  belongs_to :network
end

class Network
  include DataMapper::Resource
  
  property :id,   String, :key => true
  property :name, String, :key => true
  
  has n, :friends
end

describe DataMapper::Adapters::SimpleDBAdapter do
  before(:each) do
    @friend_attrs = { :id => "person-#{Time.now.to_f.to_s}", :name => 'Jeremy Boles', :age  => 25, :wealth => 25.00, :birthday => Date.today }
    @friend = Friend.new(@friend_attrs)
  end
  
  it 'should create a record' do
    @friend.save.should be_true
    @friend.id.should_not be_nil
    @friend.destroy
  end
  
  describe 'with a saved record' do
    before(:each) { @friend.save; sleep(0.4) } #sleep or it might not be on SDB at when the test checks it
    after(:each)  { @friend.destroy; sleep(0.4) } #same issues for the next test could still be there
    
    it 'should get a record' do
      person = Friend.get!(@friend.id, @friend.name)
      person.should_not be_nil
      person.wealth.should == @friend.wealth
    end
    
    it 'should not get records of the wrong type by id' do
      Network.get(@friend.id, @friend.name).should == nil
      lambda { Network.get!(@friend.id, @friend.name) }.should raise_error(DataMapper::ObjectNotFoundError)
    end    

    it 'should update a record' do
      person = Friend.get!(@friend.id, @friend.name)
      person.wealth = 100.00
      person.save
      sleep(0.3)
      person = Friend.get!(@friend.id, @friend.name)
      person.wealth.should_not == @friend.wealth
      person.age.should == @friend.age
      person.id.should == @friend.id
      person.name.should == @friend.name
    end

    it 'should destroy a record' do
      @friend.destroy.should be_true
      sleep(0.4) #make sure SDB propigates change
      lambda {Friend.get!(@friend.id, @friend.name)}.should raise_error(DataMapper::ObjectNotFoundError)
      persons = Friend.all(:name => @friend.name)
      persons.length.should == 0
    end

    describe '#query' do
      before(:each) do
        @domain = Friend.repository(:default).adapter.uri[:domain]
      end
      it "should return an array of records" do
        records = Friend.repository(:default).adapter.query("SELECT age, wealth from #{@domain} where age = '25'")
        records.should == [{"wealth"=>["25.0"], "age"=>["25"]}]
      end
      it "should return empty array if no matches" do
        records = Friend.repository(:default).adapter.query("SELECT age, wealth from #{@domain} where age = '15'")
        records.should be_empty
      end
      it "should raise an error if query is invalid" do
        lambda do
          records = Friend.repository(:default).adapter.query("SELECT gaga")
        end.should raise_error(RightAws::AwsError)
      end
    end
  end
end
