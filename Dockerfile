FROM ruby
RUN apt-get update
RUN apt-get install -y \
  default-libmysqlclient-dev \
  libpq-dev \
  sqlite3 \
  uuid-dev

WORKDIR /usr/src/app
ARG GIT=development
COPY Gemfile Gemfile.lock swift.gemspec ./
RUN bundle install
