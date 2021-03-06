# **Tire** provides rich and comfortable Ruby API for the
# [_ElasticSearch_](http://www.elasticsearch.org/) search engine/database.
#
# _ElasticSearch_ is a scalable, distributed, cloud-ready, highly-available
# full-text search engine and database, communicating by JSON over RESTful HTTP,
# based on [Lucene](http://lucene.apache.org/), written in Java.
#
# <img src="http://github.com/favicon.ico" style="position:relative; top:2px">
# _Tire_ is open source, and you can download or clone the source code
# from <https://github.com/karmi/tire>.
#
# By following these instructions you should have the search running
# on a sane operation system in less then 10 minutes.

# Note, that this file can be executed directly:
#
#     ruby examples/tire-dsl.rb
#


#### Installation

# Install _Tire_ with Rubygems.

#
#     gem install tire
#
require 'rubygems'
require 'tire'

#### Prerequisites

# You'll need a working and running _ElasticSearch_ server. Thankfully, that's easy.
( puts <<-"INSTALL" ; exit(1) ) unless (RestClient.get('http://localhost:9200') rescue false)

 [ERROR] You don’t appear to have ElasticSearch installed. Please install and launch it with the following commands:

 curl -k -L -o elasticsearch-0.16.0.tar.gz http://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-0.16.0.tar.gz
 tar -zxvf elasticsearch-0.16.0.tar.gz
 ./elasticsearch-0.16.0/bin/elasticsearch -f
INSTALL

### Storing and indexing documents

# Let's initialize an index named “articles”.
#
Tire.index 'articles' do
  # To make sure it's fresh, let's delete any existing index with the same name.
  #
  delete
  # And then, let's create it.
  #
  create

  # We want to store and index some articles with `title`, `tags` and `published_on` properties.
  # Simple Hashes are OK.
  #
  store :title => 'One',   :tags => ['ruby'],           :published_on => '2011-01-01'
  store :title => 'Two',   :tags => ['ruby', 'python'], :published_on => '2011-01-02'
  store :title => 'Three', :tags => ['java'],           :published_on => '2011-01-02'
  store :title => 'Four',  :tags => ['ruby', 'php'],    :published_on => '2011-01-03'

  # We force refreshing the index, so we can query it immediately.
  #
  refresh
end

# We may want to define a specific [mapping](http://www.elasticsearch.org/guide/reference/api/admin-indices-create-index.html)
# for the index.

Tire.index 'articles' do
  # To do so, just pass a Hash containing the specified mapping to the `Index#create` method.
  #
  create :mappings => {

    # Specify for which type of documents this mapping should be used.
    # (The documents must provide a `type` method or property then.)
    #
    :article => {
      :properties => {

        # Specify the type of the field, whether it should be analyzed, etc.
        #
        :id       => { :type => 'string', :index => 'not_analyzed', :include_in_all => false },

        # Set the boost or analyzer settings for the field, ... The _ElasticSearch_ guide
        # has [more information](http://elasticsearch.org/guide/reference/mapping/index.html)
        # about this. Proper mapping is key to efficient and effective search.
        # But don't fret about getting the mapping right the first time, you won't.
        # In most cases, the default mapping is just fine for prototyping.
        #
        :title    => { :type => 'string', :analyzer => 'snowball', :boost => 2.0             },
        :tags     => { :type => 'string', :analyzer => 'keyword'                             },
        :content  => { :type => 'string', :analyzer => 'czech'                               }
      }
    }
  }
end

#### Bulk Storage

# Of course, we may have large amounts of data, and adding them to the index one by one really isn't the best idea.
# We can use _ElasticSearch's_ [bulk storage](http://www.elasticsearch.org/guide/reference/api/bulk.html)
# for importing the data.

# So, for demonstration purposes, let's suppose we have a plain collection of hashes to store.
#
articles = [

  # Notice that such objects must have an `id` property!
  #
  { :id => '1', :title => 'one',   :tags => ['ruby'],           :published_on => '2011-01-01' },
  { :id => '2', :title => 'two',   :tags => ['ruby', 'python'], :published_on => '2011-01-02' },
  { :id => '3', :title => 'three', :tags => ['java'],           :published_on => '2011-01-02' },
  { :id => '4', :title => 'four',  :tags => ['ruby', 'php'],    :published_on => '2011-01-03' }
]

# We can just push them into the index in one go.
#
Tire.index 'articles' do
  import articles
end

# Of course, we can easily manipulate the documents before storing them in the index.
#
Tire.index 'articles' do
  delete

  # ... by just passing a block to the `import` method. The collection will
  # be available in the block argument.
  #
  import articles do |documents|

    # We will capitalize every _title_ and return the manipulated collection
    # back to the `import` method.
    #
    documents.map { |document| document.update(:title => document[:title].capitalize) }
  end

  refresh
end

### Searching

# With the documents indexed and stored in the _ElasticSearch_ database, we can search them, finally.
#
# Tire exposes the search interface via simple domain-specific language.


#### Simple Query String Searches

# We can do simple searches, like searching for articles containing “One” in their title.
#
s = Tire.search('articles') do
  query do
    string "title:One"
  end
end

# The results:
#     * One [tags: ruby]
#
s.results.each do |document|
  puts "* #{ document.title } [tags: #{document.tags.join(', ')}]"
end

# Or, we can search for articles published between January, 1st and January, 2nd.
#
s = Tire.search('articles') do
  query do
    string "published_on:[2011-01-01 TO 2011-01-02]"
  end
end

# The results:
#     * One [published: 2011-01-01]
#     * Two [published: 2011-01-02]
#     * Three [published: 2011-01-02]
#
s.results.each do |document|
  puts "* #{ document.title } [published: #{document.published_on}]"
end

# Of course, we may write the blocks in shorter notation.
# Local variables from outer scope are passed down the chain.

# Let's search for articles whose titles begin with letter “T”.
#
q = "title:T*"
s = Tire.search('articles') { query { string q } }

# The results:
#     * Two [tags: ruby, python]
#     * Three [tags: java]
#
s.results.each do |document|
  puts "* #{ document.title } [tags: #{document.tags.join(', ')}]"
end

# In fact, we can use any valid [Lucene query syntax](http://lucene.apache.org/java/3_0_3/queryparsersyntax.html)
# for the query string queries.

# For debugging, we can display the JSON which is being sent to _ElasticSearch_.
#
#     {"query":{"query_string":{"query":"title:T*"}}}
#
puts "", "Query:", "-"*80
puts s.to_json

# Or better, we may display a complete `curl` command to recreate the request in terminal,
# so we can see the naked response, tweak request parameters and meditate on problems.
#
#     curl -X POST "http://localhost:9200/articles/_search?pretty=true" \
#          -d '{"query":{"query_string":{"query":"title:T*"}}}'
#
puts "", "Try the query in Curl:", "-"*80
puts s.to_curl


### Logging

# For debugging more complex situations, we can enable logging, so requests and responses
# will be logged using this `curl`-friendly format.

Tire.configure do

  # By default, at the _info_ level, only the `curl`-format of request and
  # basic information about the response will be logged:
  #
  #     # 2011-04-24 11:34:01:150 [CREATE] ("articles")
  #     #
  #     curl -X POST "http://localhost:9200/articles"
  #     
  #     # 2011-04-24 11:34:01:152 [200]
  #
  logger 'elasticsearch.log'

  # For debugging, we can switch to the _debug_ level, which will log the complete JSON responses.
  #
  # That's very convenient if we want to post a recreation of some problem or solution
  # to the mailing list, IRC channel, etc.
  #
  logger 'elasticsearch.log', :level => 'debug'

  # Note that we can pass any [`IO`](http://www.ruby-doc.org/core/classes/IO.html)-compatible Ruby object as a logging device.
  #
  logger STDERR
end

### Configuration

# As we have just seen with logging, we can configure various parts of _Tire_.
#
Tire.configure do

  # First of all, we can configure the URL for _ElasticSearch_.
  #
  url "http://search.example.com"

  # Second, we may want to wrap the result items in our own class.
  #
  class MySpecialWrapper; end
  wrapper MySpecialWrapper

  # Finally, we can reset one or all configuration settings to their defaults.
  #
  reset

end


### Complex Searching

#### Other Types of Queries

# Query strings are convenient for simple searches, but we may want to define our queries more expressively,
# using the _ElasticSearch_ [Query DSL](http://www.elasticsearch.org/guide/reference/query-dsl/index.html).
#
s = Tire.search('articles') do

  # Let's suppose we want to search for articles with specific _tags_, in our case “ruby” _or_ “python”.
  #
  query do

    # That's a great excuse to use a [_terms_](http://elasticsearch.org/guide/reference/query-dsl/terms-query.html)
    # query.
    #
    terms :tags, ['ruby', 'python']
  end
end

# The search, as expected, returns three articles, all tagged “ruby” — among other tags:
#
#     * Two [tags: ruby, python]
#     * One [tags: ruby]
#     * Four [tags: ruby, php]
#
s.results.each do |document|
  puts "* #{ document.title } [tags: #{document.tags.join(', ')}]"
end

# What if we wanted to search for articles tagged both “ruby” _and_ “python”?
#
s = Tire.search('articles') do
  query do

    # That's a great excuse to specify `minimum_match` for the query.
    #
    terms :tags, ['ruby', 'python'], :minimum_match => 2
  end
end

# The search, as expected, returns one article, tagged with _both_ “ruby” and “python”:
#
#     * Two [tags: ruby, python]
#
s.results.each do |document|
  puts "* #{ document.title } [tags: #{document.tags.join(', ')}]"
end

# _ElasticSearch_ supports many types of [queries](http://www.elasticsearch.org/guide/reference/query-dsl/).
#
# Eventually, _Tire_ will support all of them. So far, only these are supported:
#
# * [string](http://www.elasticsearch.org/guide/reference/query-dsl/query-string-query.html)
# * [term](http://elasticsearch.org/guide/reference/query-dsl/term-query.html)
# * [terms](http://elasticsearch.org/guide/reference/query-dsl/terms-query.html)
# * [all](http://www.elasticsearch.org/guide/reference/query-dsl/match-all-query.html)
# * [ids](http://www.elasticsearch.org/guide/reference/query-dsl/ids-query.html)

#### Faceted Search

# _ElasticSearch_ makes it trivial to retrieve complex aggregated data from our index/database,
# so called [_facets_](http://www.elasticsearch.org/guide/reference/api/search/facets/index.html).

# Let's say we want to display article counts for every tag in the database.
# For that, we'll use a _terms_ facet.

#
s = Tire.search 'articles' do

  # We will search for articles whose title begins with letter “T”,
  #
  query { string 'title:T*' }

  # and retrieve the counts “bucketed” by `tags`.
  #
  facet 'tags' do
    terms :tags
  end
end

# As we see, our query has found two articles, and if you recall our articles from above,
# _Two_ is tagged with “ruby” and “python”, while _Three_ is tagged with “java”.
#
#     Found 2 articles: Three, Two
#
# The counts shouldn't surprise us:
#
#     Counts by tag:
#     -------------------------
#     ruby       1
#     python     1
#     java       1
#
puts "Found #{s.results.count} articles: #{s.results.map(&:title).join(', ')}"
puts "Counts by tag:", "-"*25
s.results.facets['tags']['terms'].each do |f|
  puts "#{f['term'].ljust(10)} #{f['count']}"
end

# These counts are based on the scope of our current query.
# What if we wanted to display aggregated counts by `tags` across the whole database?

#
s = Tire.search 'articles' do

  # Let's repeat the search for “T”...
  #
  query { string 'title:T*' }

  facet 'global-tags' do

    # ...but set the `global` scope for the facet in this case.
    #
    terms :tags, :global => true
  end

  # We can even _combine_ facets scoped to the current query
  # with globally scoped facets — we'll just use a different name.
  #
  facet 'current-tags' do
    terms :tags
  end
end

# Aggregated results for the current query are the same as previously:
#
#     Current query facets:
#     -------------------------
#     ruby       1
#     python     1
#     java       1
#
puts "Current query facets:", "-"*25
s.results.facets['current-tags']['terms'].each do |f|
  puts "#{f['term'].ljust(10)} #{f['count']}"
end

# On the other hand, aggregated results for the global scope include also
# tags for articles not matched by the query, such as “java” or “php”:
#
#     Global facets:
#     -------------------------
#     ruby       3
#     python     1
#     php        1
#     java       1
#
puts "Global facets:", "-"*25
s.results.facets['global-tags']['terms'].each do |f|
  puts "#{f['term'].ljust(10)} #{f['count']}"
end

# _ElasticSearch_ supports many advanced types of facets, such as those for computing statistics or geographical distance.
#
# Eventually, _Tire_ will support all of them. So far, only these are supported:
#
# * [terms](http://www.elasticsearch.org/guide/reference/api/search/facets/terms-facet.html)
# * [date](http://www.elasticsearch.org/guide/reference/api/search/facets/date-histogram-facet.html)

# We have seen that _ElasticSearch_ facets enable us to fetch complex aggregations from our data.
#
# They are frequently used for another feature, „faceted navigation“.
# We can be combine query and facets with
# [filters](http://elasticsearch.org/guide/reference/api/search/filter.html),
# so the returned documents are restricted by certain criteria — for example to a specific category —,
# but the aggregation calculations are still based on the original query.


#### Filtered Search

# So, let's make our search a bit more complex. Let's search for articles whose titles begin
# with letter “T”, again, but filter the results, so only the articles tagged “ruby”
# are returned.
#
s = Tire.search 'articles' do
  
  # We will use just the same **query** as before.
  #
  query { string 'title:T*' } 

  # But we will add a _terms_ **filter** based on tags.
  #
  filter :terms, :tags => ['ruby']

  # And, of course, our facet definition.
  #
  facet('tags') { terms :tags }

end

# We see that only the article _Two_ (tagged “ruby” and “python”) is returned,
# _not_ the article _Three_ (tagged “java”):
#
#     * Two [tags: ruby, python]
#
s.results.each do |document|
  puts "* #{ document.title } [tags: #{document.tags.join(', ')}]"
end

# The _count_ for article _Three_'s tags, “java”, on the other hand, _is_ in fact included:
#
#     Counts by tag:
#     -------------------------
#     ruby       1
#     python     1
#     java       1
#
puts "Counts by tag:", "-"*25
s.results.facets['tags']['terms'].each do |f|
  puts "#{f['term'].ljust(10)} #{f['count']}"
end

#### Sorting

# By default, the results are sorted according to their relevancy.
#
s = Tire.search('articles') { query { string 'tags:ruby' } }

s.results.each do |document|
  puts "* #{ document.title } " +
       "[tags: #{document.tags.join(', ')}; " +

       # The score is available as the `_score` property.
       #
       "score: #{document._score}]"
end

# The results:
#
#     * One [tags: ruby; score: 0.30685282]
#     * Four [tags: ruby, php; score: 0.19178301]
#     * Two [tags: ruby, python; score: 0.19178301]

# But, what if we want to sort the results based on some other criteria,
# such as published date or product price? We can do that.
#
s = Tire.search 'articles' do

  # We will search for articles tagged “ruby”, again, ...
  #
  query { string 'tags:ruby' } 

   # ... but will sort them by their `title`, in descending order.
   #
  sort { title 'desc' }
end

# The results:
#
#     * Two
#     * One
#     * Four
#
s.results.each do |document|
  puts "* #{ document.title }"
end

# Of course, it's possible to combine more fields in the sorting definition.

s = Tire.search 'articles' do

  # We will just get all articles in this case.
  #
  query { all } 

  sort do

    # We will sort the results by their `published_on` property in _ascending_ order (the default),
    #
    published_on

    # and by their `title` property, in _descending_ order.
    #
    title 'desc'
  end
end

# The results:
#     * One         (Published on: 2011-01-01)
#     * Two         (Published on: 2011-01-02)
#     * Three       (Published on: 2011-01-02)
#     * Four        (Published on: 2011-01-03)
#
s.results.each do |document|
  puts "* #{ document.title.ljust(10) }  (Published on: #{ document.published_on })"
end

#### Highlighting

# Often, we want to highlight the snippets matching our query in the displayed results.
# _ElasticSearch_ provides rich
# [highlighting](http://www.elasticsearch.org/guide/reference/api/search/highlighting.html)
# features, and _Tire_ makes them trivial to use.
#
s = Tire.search 'articles' do

  # Let's search for documents containing word “Two” in their titles,
  query { string 'title:Two' } 

   # and instruct _ElasticSearch_ to highlight relevant snippets.
   #
  highlight :title
end

# The results:
#     Title: Two; Highlighted: <em>Two</em>
#
s.results.each do |document|
  puts "Title: #{ document.title }; Highlighted: #{document.highlight.title}"
end

# We can configure many options for highlighting, such as:
#
s = Tire.search 'articles' do
  query { string 'title:Two' }

  # • specify the fields to highlight
  #
  highlight :title, :body

  # • specify their individual options
  #
  highlight :title, :body => { :number_of_fragments => 0 }

  # • or specify global highlighting options, such as the wrapper tag
  #
  highlight :title, :body, :options => { :tag => '<strong class="highlight">' }
end


### ActiveModel Integration

# As you can see, [_Tire_](https://github.com/karmi/tire) supports the
# main features of _ElasticSearch_ in Ruby.
#
# It allows you to create and delete indices, add documents, search them, retrieve the facets, highlight the results,
# and comes with a usable logging facility.
#
# Of course, the holy grail of any search library is easy, painless integration with your Ruby classes, and,
# most importantly, with ActiveRecord/ActiveModel classes.
#
# Please, check out the [README](https://github.com/karmi/tire/tree/master#readme) file for instructions
# how to include _Tire_-based search in your models..
#
# Send any feedback via Github issues, or ask questions in the [#elasticsearch](irc://irc.freenode.net/#elasticsearch) IRC channel.
