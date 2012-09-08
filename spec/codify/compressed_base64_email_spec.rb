# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'spec_helper'

describe 'CompressedBase64Email' do
  before(:all) do
    ActiveRecord::Base.connection.create_table :compressed_base64_emails do |t|
      t.string :from
      t.string :to
      t.string :subject
      t.text :compressed_body
    end
    class CompressedBase64Email < ActiveRecord::Base
      include Codify::ModelAdditions
      attr_compressor :body, :encoder => [:zlib,:base64]
    end
  end
  after(:all) do
    ActiveRecord::Base.connection.drop_table :compressed_base64_emails
  end

  it 'can set compressed body' do
    email = CompressedBase64Email.new
    body = "My new email body"
    email.body = body
    email.body.should == body
    email.body_changed?.should be_true
  end
  it 'can construct and compress new email with body' do
    body = "My email body set on initialization"
    email = CompressedBase64Email.new( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Test", :body => body )
    email.body_changed?.should be_true
    email.compressed_body_changed?.should be_true
    email.compressed_body.should_not be_blank
  end
  it 'can save email with compressed body and uncompress the body again' do
    body = "My email body set on initialization"
    email = CompressedBase64Email.create( :from => "initializer@email.class", :to => "codify@email.class", :subject => "Test", :body => body )
    email = CompressedBase64Email.find(email.id)
    email.body.should == body
  end
  it 'compresses body correctly' do
    email = CompressedBase64Email.new
    body = "My new email body"
    email.body = body
    CompressedBase64Email.uncompress_body(email.compressed_body).should == body
  end
  it 'is base64 encoded once compressed' do
    compressed_body = CompressedBase64Email.compress_body("Test compression")
    compressed_body.match(/\A[\w\/+\n]*=*\n?\z/).should_not be_nil # should match base64 encoding characters
  end
end
