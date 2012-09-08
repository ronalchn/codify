# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'spec_helper'

describe 'Base64Token' do
  before(:all) do
    ActiveRecord::Base.connection.create_table :base64_tokens do |t|
      t.string :encoded_token
      t.string :encoded_url_token
      t.timestamps
    end
    class Base64Token < ActiveRecord::Base
      include Codify::ModelAdditions
      attr_encoder :token, :encoder => :base64
      attr_encoder :url_token, :encoder => :base64, :representation => :urlsafe
    end
  end
  after(:all) do
    ActiveRecord::Base.connection.drop_table :base64_tokens
  end

  it 'can set base64 token' do
    base64_token = Base64Token.new
    token = "Important key information"
    base64_token.token = token
    base64_token.token.should == token
    base64_token.encoded_token.should_not == token
    Base64Token.encode_token(token) == base64_token.encoded_token
  end
  it 'can decode token' do
    token = "Important key information"
    base64_token = Base64Token.create(:token => token)
    base64_token = Base64Token.find(base64_token.id)
    base64_token.token.should == token
  end
  context 'ruby 1.9+' do
    it 'can set url safe base64 token' do
      base64_token = Base64Token.new
      token = "Important key information"
      base64_token.url_token = token
      base64_token.url_token.should == token
      base64_token.encoded_url_token.should_not == token
      Base64Token.encode_url_token(token) == base64_token.encoded_url_token
    end
    it 'base64 and url safe base64 are not the same' do
      token = "Important key information"
      Base64Token.encode_url_token(token).should_not == Base64Token.encode_token(token)
    end
  end if RUBY_VERSION != '1.8.7'
end
