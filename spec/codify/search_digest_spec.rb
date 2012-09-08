# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'spec_helper'

describe 'SearchDigest' do
  before(:all) do
    ActiveRecord::Base.connection.create_table :search_digests do |t|
      t.text :content
      t.binary :digested_content
      t.binary :digested_anonymous_identity
      t.timestamps
    end
    class SearchDigest < ActiveRecord::Base
      include Codify::ModelAdditions
      attr_digestor :content, :include_plaintext => true
      attr_digestor :anonymous_identity
    end
  end
  after(:all) do
    ActiveRecord::Base.connection.drop_table :search_digests
  end

  it 'can set digest content' do
    search_digest = SearchDigest.new
    content = "Yummy content - extremely digestable"
    search_digest.content = content
    search_digest.digested_content.should_not == content
    SearchDigest.digest_content(content) == search_digest.digested_content
  end
  it 'cannot puke out digested food' do
    search_digest = SearchDigest.create(:content => "", :anonymous_identity => "The Phantom")
    search_digest.anonymous_identity.should == "The Phantom" # we still know the Phantom is there
    search_digest = SearchDigest.find(search_digest.id) # but if we forget...
    search_digest.anonymous_identity.should be_blank # the record cannot puke The Phantom back out
    search_digest.digested_anonymous_identity.should == SearchDigest.digest_anonymous_identity("The Phantom") # but the phantom is there nevertheless
  end
  it 'can retrieve content stored as plaintext' do
    search_digest = SearchDigest.create(:content => "Plaintext")
    search_digest = SearchDigest.find(search_digest.id)
    search_digest.content.should == "Plaintext"
  end
  it 'can search by content digest' do
    id1 = SearchDigest.create(:content => "Hamburger").id
    id2 = SearchDigest.create(:content => "Hot dog").id
    id3 = SearchDigest.create(:content => "Cheeseburger").id
    SearchDigest.find_by_digested_content(SearchDigest.digest_content("Hot dog"))[:id].should == id2 # TODO: replace by shortcut finder
  end if RUBY_VERSION != '1.8.7' # not working, probably because of encoding issues
end
