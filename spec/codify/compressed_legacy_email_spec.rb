require 'spec_helper'

# this spec checks that an ActiveRecord model with a legacy un-compressed column which should now be compressed
# will still work appropriately - compressing the column for new objects, even as the original object's columns
# are left un-compressed

describe 'CompressedLegacyEmail' do
  before(:all) do
    ActiveRecord::Base.connection.create_table :legacy_emails do |t|
      t.string :from
      t.string :to
      t.string :subject
      t.text :body # legacy column for old uncompressed bodies
      t.binary :compressed_body # new column for compressed bodies
    end
    class LegacyEmail < ActiveRecord::Base # used to test data with direct access to database
    end
    class CompressedLegacyEmail < LegacyEmail
      include Codify::ModelAdditions
      attr_compressor :body
    end
  end
  after(:all) do
    ActiveRecord::Base.connection.drop_table :legacy_emails
  end

  it 'reading body is nil for new email' do
    email = CompressedLegacyEmail.new
    email.body.should be_nil
  end
  it 'body initially unchanged' do
    email = CompressedLegacyEmail.new
    email.body_changed?.should be_false
    email.body_change.should be_nil
  end
  it 'cannot set compressed body attribute directly' do
    email = CompressedLegacyEmail.new
    expect do
      email.compressed_body = "My new body" # throws NoMethodError exception
    end.to raise_exception(NoMethodError)
  end
  it 'can save email with compressed body only' do
    body = "My email body set on initialization"
    email = CompressedLegacyEmail.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Test initialization compression", :body => body )
    email = CompressedLegacyEmail.find(email.id) # re-load from database
    email.body.should == body
    # check that only compressed body is saved
    legacy_email = LegacyEmail.find(email.id)
    legacy_email.body.should be_blank
    legacy_email.compressed_body.should_not be_blank
  end
  it 'can read legacy email with uncompressed body' do
    body = "My email body set on initialization"
    legacy_email = LegacyEmail.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Uncompressed email", :body => body )
    legacy_email.compressed_body.should be_nil
    email = CompressedLegacyEmail.find(legacy_email.id)
    email.body.should == body
  end
  it 'can save compressed body for initially uncompressed legacy email' do
    body = "My email body set on initialization"
    legacy_email = LegacyEmail.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Uncompressed email", :body => body )
    email = CompressedLegacyEmail.find(legacy_email.id)
    new_body = "New body which will be compressed!"
    email.body = new_body
    email.save
    legacy_email.reload.body.should be_blank
    legacy_email.compressed_body.should_not be_blank
    email.reload.body.should == new_body
  end
end
