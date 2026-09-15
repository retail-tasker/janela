# Builds the demo: the test/dummy host application running this engine.
# Not part of the gem. See test/dummy/config/deploy.yml.
ARG RUBY_VERSION=3.4.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile janela.gemspec ./
COPY lib/janela/version.rb lib/janela/version.rb
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN cd test/dummy && SECRET_KEY_BASE=precompile ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p test/dummy/storage test/dummy/tmp test/dummy/log && \
    chown -R rails:rails test/dummy/storage test/dummy/tmp test/dummy/log test/dummy/db
USER 1000:1000

WORKDIR /rails/test/dummy
ENTRYPOINT ["/rails/test/dummy/bin/docker-entrypoint"]

ENV PORT=3000
EXPOSE 3000
CMD ["./bin/rails", "server"]
