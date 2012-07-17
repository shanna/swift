Swift
=====

* [source](http://github.com/shanna/swift)
* [documentation](http://rubydoc.info/gems/swift/file/README.md)

## Description

A rational rudimentary object relational mapper.

## Dependencies

* ruby   >= 1.9.1
* [dbic++](http://github.com/deepfryed/dbicpp) >= 0.6.1
* mysql  >= 5.0.17, postgresql >= 8.4 or sqlite3 >= 3.7

## Installation

Install dbic++ first. Grab the latest [dbic++](https://github.com/deepfryed/dbicpp) source tarball and
unpack it. Installation instructions for dbic++ under two most popular unices are given below.

### dbic++ on Linux (debian flavours)

```
sudo apt-get install build-essential
sudo apt-get install cmake libpcre3-dev uuid-dev
sudo apt-get install libmysqlclient-dev libpq-dev libsqlite3-dev

cd dbicpp/
sudo ./build -i
```

### dbic++ on MacOSX

Assuming you already have homebrew. If not head to https://github.com/mxcl/homebrew/wiki/installation

```
brew install cmake
brew install pcre
brew install ossp-uuid
brew install postgresql
brew install mysql
brew install sqlite3

cd dbicpp/
sudo ./build -i
```

### Install swift

```
gem install swift
```

## Features

* Multiple databases.
* Prepared statements.
* Bind values.
* Transactions and named save points.
* Asynchronous API for PostgreSQL and MySQL.
* IdentityMap.
* Migrations.

## Performance notes

1. The current version creates DateTime objects for timestamp fields and this is roughly 80% slower on
   rubies older than 1.9.3.
2. On rubies older than 1.9.3, Swift will try using [home_run](https://github.com/jeremyevans/home_run)
   for performance.
3. Record operations use prepared statements when possible. If you would like to turn it off, you can
   pass `prepare_sql: false` in the `Adapter` connection options.

### DB

```ruby
  require 'swift'

  Swift.trace true # Debugging.
  Swift.setup :default, Swift::Adapter::Postgres, db: 'swift'

  # Block form db context.
  Swift.db do |db|
    db.execute('drop table if exists users')
    db.execute('create table users(id serial, name text, email text)')

    # Save points are supported.
    db.transaction :named_save_point do
      st = db.prepare('insert into users (name, email) values (?, ?) returning id')
      puts st.execute('Apple Arthurton', 'apple@arthurton.local').insert_id
      puts st.execute('Benny Arthurton', 'benny@arthurton.local').insert_id
    end

    # Block result iteration.
    db.prepare('select * from users').execute do |row|
      puts row.inspect
    end

    # Enumerable.
    result = db.prepare('select * from users where name like ?').execute('Benny%')
    puts result.first
  end
```

### DB Record Operations

Rudimentary object mapping. Provides a definition to the db methods for prepared (and cached) statements plus native
primitive Ruby type conversion.

```ruby
  require 'swift'
  require 'swift/migrations'

  Swift.trace true # Debugging.
  Swift.setup :default, Swift::Adapter::Postgres, db: 'swift'

  class User < Swift::Record
    store     :users
    attribute :id,         Swift::Type::Integer, serial: true, key: true
    attribute :name,       Swift::Type::String
    attribute :email,      Swift::Type::String
    attribute :updated_at, Swift::Type::DateTime
  end # User

  Swift.db do |db|
    db.migrate! User

    # Select Record instance (relation) instead of Hash.
    users = db.prepare(User, 'select * from users limit 1').execute

    # Make a change and update.
    users.each{|user| user.updated_at = Time.now}
    db.update(User, *users)

    # Get a specific user by id.
    user = db.get(User, id: 1)
    puts user.name, user.email
  end
```

### Record CRUD

Record/relation level helpers.

```ruby
  require 'swift'
  require 'swift/migrations'

  Swift.trace true # Debugging.
  Swift.setup :default, Swift::Adapter::Postgres, db: 'swift'

  class User < Swift::Record
    store     :users
    attribute :id,    Swift::Type::Integer, serial: true, key: true
    attribute :name,  Swift::Type::String
    attribute :email, Swift::Type::String
  end # User

  # Migrate it.
  User.migrate!

  # Create
  User.create name: 'Apple Arthurton', email: 'apple@arthurton.local' # => User

  # Get by key.
  user = User.get id: 1

  # Alter attribute and update in one.
  user.update name: 'Jimmy Arthurton'

  # Alter attributes and update.
  user.name = 'Apple Arthurton'
  user.update

  # Destroy
  user.delete
```

### Conditions SQL syntax.

SQL is easy and most people know it so Swift ORM provides simple #to_s
attribute to table and field name typecasting.

```ruby
  class User < Swift::Record
    store     :users
    attribute :id,    Swift::Type::Integer, serial: true, key: true
    attribute :age,   Swift::Type::Integer, field: 'ega'
    attribute :name,  Swift::Type::String,  field: 'eman'
    attribute :email, Swift::Type::String,  field: 'liame'
  end # User

  # Convert :name and :age to fields.
  # select * from users where eman like '%Arthurton' and ega > 20
  users = User.execute(
    %Q{select * from #{User} where #{User.name} like ? and #{User.age} > ?},
    '%Arthurton', 20
  )
```

### Identity Map

Swift comes with a simple identity map. Just require it after you load swift.

```ruby
  require 'swift'
  require 'swift/identity_map'
  require 'swift/migrations'

  class User < Swift::Record
    store     :users
    attribute :id,    Swift::Type::Integer, serial: true, key: true
    attribute :age,   Swift::Type::Integer, field: 'ega'
    attribute :name,  Swift::Type::String,  field: 'eman'
    attribute :email, Swift::Type::String,  field: 'liame'
  end # User

  # Migrate it.
  User.migrate!

  # Create
  User.create name: 'James Arthurton', email: 'james@arthurton.local' # => User

  find_user = User.prepare(%Q{select * from #{User} where #{User.name = ?})
  find_user.execute('James Arthurton')
  find_user.execute('James Arthurton') # Gets same object reference
```

### Bulk inserts

Swift comes with adapter level support for bulk inserts for MySQL and PostgreSQL. This
is usually very fast (~5-10x faster) than regular prepared insert statements for larger
sets of data.

MySQL adapter - Overrides the MySQL C API and implements its own _infile_ handlers. This
means currently you *cannot* execute the following SQL using Swift

```sql
  LOAD DATA LOCAL INFILE '/tmp/users.tab' INTO TABLE users;
```

But you can do it almost as fast in ruby,

```ruby
  require 'swift'

  Swift.setup :default, Swift::Adapter::Mysql, db: 'swift'

  # MySQL packet size is the usual limit, 8k is the packet size by default.
  Swift.db do |db|
    File.open('/tmp/users.tab') do |file|
      count = db.write('users', %w{name email balance}, file)
    end
  end
```

You are not just limited to files - you can stream data from anywhere into your database without
creating temporary files.

### Asynchronous API

`Swift::Adapter#async_execute` returns a `Swift::Result` instance. You can either poll the corresponding
`Swift::Adapter#fileno` and then call `Swift::Result#retrieve` when ready or use a block form like below
which implicitly uses `rb_thread_wait_fd`

```ruby
  require 'swift'

  pool = 3.times.map.with_index {|n| Swift.setup n, Swift::Adapter::Postgres, db: 'swift' }

  Thread.new do
    pool[0].async_execute('select pg_sleep(3), 1 as qid') {|row| p row}
  end

  Thread.new do
    pool[1].async_execute('select pg_sleep(2), 2 as qid') {|row| p row}
  end

  Thread.new do
    pool[2].async_execute('select pg_sleep(1), 3 as qid') {|row| p row}
  end

  Thread.list.reject {|thread| Thread.current == thread}.each(&:join)
```

or use the `swift/eventmachine` api.

```ruby
  require 'swift/eventmachine'

  EM.run do
    pool = 3.times.map { Swift.setup(:default, Swift::Adapter::Postgres, db: "swift") }

    3.times.each do |n|
      defer = pool[n].execute("select pg_sleep(3 - #{n}), #{n + 1} as qid")

      defer.callback do |res|
        p res.first
      end

      defer.errback do |e|
        p 'error', e
      end
    end
  end
```

or use the `em-synchrony` api for `swift`

```ruby
  require 'swift/synchrony'

  EM.run do
    3.times.each do |n|
      EM.synchrony do
        db     = Swift.setup(:default, Swift::Adapter::Postgres, db: "swift")
        result = db.execute("select pg_sleep(3 - #{n}), #{n + 1} as qid")

        p result.first
        EM.stop if n == 0
      end
    end
  end
```

## Performance

Swift prefers performance when it doesn't compromise the Ruby-ish interface. It's unfair to compare Swift to DataMapper
and ActiveRecord which suffer under the weight of support for many more databases and legacy/alternative Ruby
implementations. That said obviously if Swift were slower it would be redundant so benchmark code does exist in
http://github.com/shanna/swift/tree/master/benchmarks

### Benchmarks

#### ORM

The test environment:

* ruby 1.9.3p0
* Intel Core2Duo P8700 2.53GHz, 4G RAM and Kingston SATA2 SSD

The test setup:

* 10,000 rows are created once.
* All the rows are selected once.
* All the rows are selected once and updated once.
* Memory footprint(rss) shows how much memory the benchmark used with GC disabled.
  This gives an idea of total memory use and indirectly an idea of the number of
  objects allocated and the pressure on Ruby GC if it were running. When GC is enabled,
  the actual memory consumption might be much lower than the numbers below.

```
    ./simple.rb -n1 -r10000 -s ar -s dm -s sequel -s swift

    benchmark       sys     user    total  real      rss
    ar #create      0.75    7.18    7.93   10.5043   366.95m
    ar #select      0.07    0.26    0.33    0.3680    40.71m
    ar #update      0.96    7.92    8.88   11.7537   436.38m

    dm #create      0.33    3.73    4.06    5.0908   245.68m
    dm #select      0.08    1.51    1.59    1.6154    87.95m
    dm #update      0.44    7.09    7.53    8.8685   502.77m

    sequel #create  0.60    5.07    5.67    7.9804   236.69m
    sequel #select  0.02    0.12    0.14    0.1778    12.75m
    sequel #update  0.82    4.95    5.77    8.2062   230.00m

    swift #create   0.27    0.59    0.86    1.5085    84.85m
    swift #select   0.03    0.06    0.09    0.1037    11.24m
    swift #update   0.20    0.69    0.89    1.5867    62.19m

    -- bulk insert api --
    swift #write    0.04    0.06    0.10    0.1699    14.05m
```

## TODO

* More tests.
* Assertions for dumb stuff.
* Auto-generate schema?
* Move examples to Wiki. Examples of models built on top of Schema.

## Contributing

Go nuts! There is no style guide and I do not care if you write tests or comment code. If you write something neat just
send a pull request, tweet, email or yell it at me line by line in person.
