task :cron do
  # Just want to run the script
  require './lib/populate_db.rb'
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/*_test.rb']
  t.verbose = true
end

