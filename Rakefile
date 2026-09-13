require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"

require "minitest/test_task"

Minitest::TestTask.create do |t|
  t.test_globs = Dir["test/**/*_test.rb"] - Dir["test/system/**/*_test.rb"]
  t.warning = false
end

Minitest::TestTask.create(:system) do |t|
  t.test_globs = [ "test/system/**/*_test.rb" ]
  t.warning = false
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

task default: %i[test rubocop]
