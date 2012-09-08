# Codify

[![Build Status](https://secure.travis-ci.org/ronalchn/codify.png?branch=master)](http://travis-ci.org/ronalchn/codify)

Transparently encodes text before saving to your database. Automatically encodes any desired text attributes for saving to database, and decodes when retrieving the field. Includes encoding for compression, encryption and error checking.

Many encodings can be useful, for example, compression can be useful for large text fields, to save disk space, encryption may be used to safeguard data.

This is not suitable if you plan to do fulltext searching directly on encoded attributes, although it can still be used where a separate fulltext search engine is used.

Currently, only activerecord is supported.

## Installation

Add this line to your application''s Gemfile:

    gem 'codify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install codify

## Usage

In general, to encode an attribute, just call `attr_encoder` on the attribute:

```ruby
class DataBlock < ActiveRecord::Base
  attr_encoder :data, :encoder => :base64
end
```

Codify will now expect to save data to an <tt>encoded_data</tt> field. So you should add the column via a migration. Notice that we can now to save binary data to the database, and can use a text type, because of the <tt>Base64Encoder</tt>.

```ruby
add_column :data_blocks, :encoded_data, :text
```

Now, you can easily read or write, and leave the encoding and decoding to Codify.

```ruby
# writing
datablock = DataBlock.create(:data => "Data, could be binary, like these: \0\x43!")

# reading
datablock = DataBlock.first
datablock.data # => "Data, could be binary, ..."
```

You can change the default encoded attribute column name with <tt>:prefix</tt> and <tt>:suffix</tt> options.

Convenience methods for specific types of encoding are also available. For example, <tt>attr_compressor</tt> compresses an attribute.

```ruby
class Page < ActiveRecord::Base
  attr_compressor :body #, :encoder => :zlib # this is already the default for attr_compressor
end
```

Each method applies an appropriate set of default options:

<table>
  <tr><th>Convenience Method</th>       <th>:encoder</th>      <th>:prefix</th>         <th>:encoder_type</th>                                                                                           <th>:verb</th>       <th>:reverse_verb</th>       <th>Recommended Usage</th></tr>
  <tr><td>attr_encoder</td>    <td>:none</td>         <td>"encoded_"</td>      <td>:all</td>                                                                                                    <td>:encode</td>     <td>:decode</td>             <td>Encoding</td></tr>
  <tr><td>attr_compressor</td> <td>:zlib</td>         <td>"compressed_"</td>   <td>:compressor</td>                                                                                             <td>:compress</td>   <td>:uncompress</td>         <td>Compression</td></tr>
  <tr><td>attr_digestor</td>   <td>:sha512</td>       <td>"digested_"</td>   <td>:digestor</td>                                                                                                 <td>:digest</td>     <td>:decode (not used)</td>  <td>Digest/Hashing</td></tr>
</table>

### Options

Options can be passed to some encoders. The exact options possible depend on the encoder. Probably the easiest way is just to pass them to <tt>attr_encoder</tt> when an encoded attribute is declared.

```ruby
attr_compressor :body, :encoder => :zlib, :level => 9 # highest possible compression
```

They can also be passed when initializing an encoder object:

```ruby
attr_compressor :body, :encoder => Codify::Encoders::ZlibEncoder.new(:level => 9)
```

### Chaining Encoders

A number of encoders can be chained, to apply them one after the other for a single attribute.

```ruby
class Page < ActiveRecord::Base
  attr_compressor :body, :encoder => [:zlib, :base64]
end
```

This will first compress with <tt>ZlibEncoder</tt>, then encode the resulting binary with <tt>Base64Encoder</tt>.

### Custom Encoders

If the included encoders are not sufficient, you can use your own, just inherit from <tt>Codify::Encoders::AbstractEncoder</tt>, and define <tt>encode</tt> and <tt>decode</tt> methods. To use options which may be passed to the encoder, just call <tt>options</tt> with a symbol.

```ruby
class MyEncoder < Codify::Encoders::AbstractEncoder
  def encode(data)
    "#{options(:header)}#{data}#{options(:footer)}" # wrap data in header and footer
  end
  def decode(data)
    data[options(:header).length...options(:footer).length] # remove header and footer from data
  end
end
class Model < ActiveRecord::Base
  attr_encoder :data, :encoder => MyEncoder
end
```

Instead of passing a class to <tt>attr_encoder</tt>, it is also possible to register custom encoders with a symbol.

```ruby
Codify::Encoders.register :my_encoder, MyEncoder, :encoding
class Model < ActiveRecord::Base
  attr_encoder :data, :encoder => :my_encoder, :encoder_type => :encoding
end
```

The <tt>:encoder_type</tt> option specifies a registration namespace which will be searched first for <tt>:my_encoder</tt>. The global registration namespace will only be searched after a specific namespace does not include the desired encoder. This can be useful if multiple encoders are given the same name. If they are in different namespaces, the can still be specified.

An encoder may also be registered by passing a block to <tt>register</tt>. This can be used to dynamically register a set of symbols.

```ruby
Codify::Encoders.register MyEncoder do |symbol|
  return MyEncoder if [:myencoder, :my_encoder, :MYENCODER].include?(symbol)
  nil # if symbol is not found, return nil
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
