# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'spec_helper'

describe 'CompressedEmail' do
  before(:all) do
    ActiveRecord::Base.connection.create_table :compressed_emails do |t|
      t.string :from
      t.string :to
      t.string :subject
      t.binary :compressed_body
    end
    class CompressedEmail < ActiveRecord::Base
      include Codify::ModelAdditions
      attr_compressor :body
    end
  end
  after(:all) do
    ActiveRecord::Base.connection.drop_table :compressed_emails
  end

  it 'reading body is nil for new email' do
    email = CompressedEmail.new
    email.body.should be_nil
  end
  it 'can set compressed body' do
    email = CompressedEmail.new
    body = "My new email body"
    email.body = body
    email.body.should == body
    email.compressed_body.should_not be_nil
  end
  it 'body initially unchanged' do
    email = CompressedEmail.new
    email.body_changed?.should be_false
  end
  it 'cannot set compressed body attribute directly' do
    email = CompressedEmail.new
    expect do
      email.compressed_body = "My new body" # throws NoMethodError exception
    end.to raise_exception(NoMethodError)
  end
  it 'changes compressed body when body changed' do
    email = CompressedEmail.new
    email.compressed_body.should be_blank
    email.body = "My new email body"
    email.compressed_body.should_not be_blank
    email.compressed_body_changed?.should be_true
  end
  it 'can construct and compress new email with body' do
    body = "My email body set on initialization"
    email = CompressedEmail.new( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Test initialization compression", :body => body )
    email.body_changed?.should be_true
    email.compressed_body_changed?.should be_true
    email.compressed_body.should_not be_blank
  end
  it 'can save email with compressed body' do
    body = "My email body set on initialization"
    email = CompressedEmail.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Test initialization compression", :body => body )
    email = CompressedEmail.find(email.id)
    email.body.should == body
  end
  it 'can compress body to use less space' do
    body = "I will use less space. I will use less space. I will use less space. I will use less space... how many more lines should I write?"
    email = CompressedEmail.new( :body => body )
    email.compressed_body.length.should < body.length
  end
  it 'compresses on record and ActiveRecord class the same' do
    body = "I can be compressed by class and object"
    email = CompressedEmail.new( :body => body )
    CompressedEmail.compress_body(body).should == email.compressed_body
  end
  it 'uncompresses on record and ActiveRecord class the same' do
    body = "I can be uncompressed by class and object"
    email = CompressedEmail.new( :body => body )
    CompressedEmail.uncompress_body(email.compressed_body).should == body
  end
  context 'with email already in database' do
    before(:each) do
      @body = "Initial body that is in the database. I am very happy in the database, after I have been compressed, I can be re-inflated."
      @email_id = CompressedEmail.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Email in database", :body => @body ).id
    end
    it 'can read back body' do
      email = CompressedEmail.find(@email_id)
      email.body.should == @body
      email.body_changed?.should be_false
    end
    it 'can change body and save' do
      email = CompressedEmail.find(@email_id)
      email.body = "My new body"
      email.compressed_body_changed?.should be_true
      email.save
      email.reload.body.should_not == @body
    end
    it 'body_change shows change in body' do
      email = CompressedEmail.find(@email_id)
      email.body_change.should be_nil
      email.body = "My new body"
      email.body_change.should == [@body,email.body]
      email.body = "Another body"
      email.body_change.should == [@body,email.body]
      email.body = @body
      email.body_change.should be_nil
    end
  end
end
