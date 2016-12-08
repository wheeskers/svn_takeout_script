#!/usr/bin/ruby

require 'sqlite3'
require 'json'

begin
  $config = JSON::parse(File.read("config.json"))
rescue
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [FATAL] Incorrect JSON file or 'config.json' does not exist!"
  exit 1
end
begin
  $db = SQLite3::Database::new( $config['database'] )
rescue Exception => e
  $log.fatal{ "Something is wrong with sqlite3 db file or sqlite3 itself. Exception is: #{e}" }
  exit 2
end
case ARGV[0]
when /--last/
  mode = :normal
  limit = ARGV[0].match(/(?<=last\=)\d+/)
  limit.nil? ? limit='1' : limit=limit.to_s
  puts "Showing last #{limit} log records"
  command = "SELECT * FROM event_log ORDER BY stamp DESC LIMIT(#{limit});"
when /--all/
  mode = :normal
  puts "Showing all stored log records (1000 records limit)"
  command = "SELECT * FROM event_log LIMIT(1000);"
when /--raw/
  mode = :raw
  command = "SELECT * FROM event_log";
else
  puts "Please use one of the following flags:\n\t--last=N, --all. --raw"
  exit 0
end
res = $db.execute(command)
if mode == :raw
  puts res.inspect
elsif mode == :normal
  res.each do |t|
    puts "-"*%x[tput cols].to_i
    puts "Log ID:    #{t[0]}\nTimestamp: #{t[1]}\nEvent:     #{t[2]}\nResult:    #{t[3]}\nDetails:   #{t[4]}\nFlies:     \n\t#{t[5].split(',').join("\n\t")}"
  end
else
  puts "Unknown output mode, do nothing..."
end
$db.close
