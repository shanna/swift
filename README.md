Swift
=====

* [source](http://github.com/shanna/swift)
* [documentation](http://rubydoc.info/gems/swift/file/README.md)

## Description

A rational rudimentary object relational mapper.

## Dependencies

* MRI Ruby >= 1.9.1
* swift-db-sqlite3 or swift-db-postgres or swift-db-mysql

## Installation

### Dependencies

Install one of the following drivers you would like to use.

```
gem install swift-db-sqlite3
gem install swift-db-postgres
gem install swift-db-mysql
```

### Install Swift

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

### DB

```ruby
  require 'swift'
  require 'swift/adapter/postgres'

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
  require 'swift/adapter/postgres'
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
  require 'swift/adapter/postgres'
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
  require 'swift/adapter/postgres'
  require 'swift/identity_map'
  require 'swift/migrations'

  Swift.setup :default, Swift::Adapter::Postgres, db: 'swift'

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
  require 'swift/adapter/mysql'

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

`Swift::Adapter::Sql#query` runs a query asynchronously. You can either poll the corresponding
`Swift::Adapter::Sql#fileno` and then call `Swift::Adapter::Sql#result` when ready or use a block form like below
which implicitly uses `rb_thread_wait_fd`

```ruby
  require 'swift'
  require 'swift/adapter/postgres'

  pool = 3.times.map.with_index {|n| Swift.setup n, Swift::Adapter::Postgres, db: 'swift' }

  Thread.new do
    pool[0].query('select pg_sleep(3), 1 as qid') {|row| p row}
  end

  Thread.new do
    pool[1].query('select pg_sleep(2), 2 as qid') {|row| p row}
  end

  Thread.new do
    pool[2].query('select pg_sleep(1), 3 as qid') {|row| p row}
  end

  Thread.list.reject {|thread| Thread.current == thread}.each(&:join)
```

or use the `swift/eventmachine` api.

```ruby
  require 'swift/eventmachine'
  require 'swift/adapter/postgres'

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
  require 'swift/adapter/postgres'

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

### Fibers and Connection Pools

If you intend to use `Swift::Record` with `em-synchrony` you will need to use a fiber aware connection pool.

```ruby
require 'swift/fiber_connection_pool'

EM.run do
  Swift.setup_connection_pool 5, :default, Swift::Adapter::Postgres, db: 'swift'

  5.times do
    EM.synchrony do
      p User.execute("select * from users").entries
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

```
$ uname -a

Linux deepfryed.local 3.0.0-1-amd64 #1 SMP Sun Jul 24 02:24:44 UTC 2011 x86_64 GNU/Linux

$ cat /proc/cpuinfo | grep "processor\|model name"

processor    : 0
model name   : Intel(R) Core(TM) i7-2677M CPU @ 1.80GHz
processor    : 1
model name   : Intel(R) Core(TM) i7-2677M CPU @ 1.80GHz
processor    : 2
model name   : Intel(R) Core(TM) i7-2677M CPU @ 1.80GHz
processor    : 3
model name   : Intel(R) Core(TM) i7-2677M CPU @ 1.80GHz

$ ruby -v

ruby 1.9.3p125 (2012-02-16 revision 34643) [x86_64-linux]
```

PostgreSQL config:

```
shared_buffers           = 800MB     # min 128kB
effective_cache_size     = 512MB
work_mem                 = 64MB      # min 64kB
maintenance_work_mem     = 64MB      # min 1MB
```

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

    benchmark           sys         user       total       real        rss

    ar #create          1.960000    15.81000   17.770000   22.753109   266.21m
    ar #select          0.020000     0.38000    0.400000    0.433041    50.82m
    ar #update          2.000000    17.90000   19.900000   26.674921   317.48m

    dm #create          0.660000    11.55000   12.210000   15.592424   236.86m
    dm #select          0.030000     1.30000    1.330000    1.351911    87.18m
    dm #update          0.950000    17.25000   18.200000   22.109859   474.81m

    sequel #create      1.960000    14.48000   16.440000   23.004864   226.68m
    sequel #select      0.000000     0.09000    0.090000    0.134619    12.77m
    sequel #update      1.900000    14.37000   16.270000   22.945636   200.20m

    swift #create       0.520000     1.95000    2.470000    5.828846    75.26m
    swift #select       0.010000    0.070000    0.080000    0.095124    11.23m
    swift #update       0.440000     1.95000    2.390000    6.044971    59.35m
    swift #write        0.010000    0.050000    0.060000    0.117195    13.46m

```

## TODO

* More tests.
* Assertions for dumb stuff.
* Auto-generate schema?
* Move examples to Wiki. Examples of models built on top of Schema.

## Contributing

Go nuts! There is no style guide and I do not care if you write tests or comment code. If you write something neat just
send a pull request, tweet, email or yell it at me line by line in person.
