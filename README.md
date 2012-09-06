# Codify

Transparently compresses text before saving to your database. This gem compresses text attributes automatically, and uncompresses automatically on retrieval.

This is useful for large text fields, to save disk space. This is not suitable if you plan to do fulltext searching directly, although it can still be used where a separate fulltext search engine is used.

Currently, only activerecord is supported. The compression algorithm is zlib.

## Installation

Add this line to your application''s Gemfile:

    gem 'codify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install codify

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
