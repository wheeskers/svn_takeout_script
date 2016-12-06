#!/usr/bin/ruby

require 'logger'
require 'uri'
require 'json'

begin
  $config = JSON::parse(File.read("config.json"))
rescue
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [FATAL] Incorrect JSON file or 'config.json' does not exist!"
  exit 1
end

$log                = Logger.new("#{$config['log']['file']}")
$log.sev_threshold  = eval "Logger::#{$config['log']['level']}"
$log.progname       = 'SubversionCheckoutScript'
$log.formatter      = proc { |severity, datetime, progname, msg| "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n" }

$log.info{ "Running script (test)" }

def check_http_url(text)
  begin
    link = URI::parse(text)
  rescue Exception => e
    puts "Parse error: #{e}"
    return false
  end
  if link.kind_of?(URI::HTTPS) || link.kind_of?(URI::HTTP)
    puts "Link is valid!"
    return true
  else
    puts "HTTP or HTTPS link is not valid: make sure it has HTTP or HTTPS prefix and correct format"
    return false
  end
end

def parse_in_file(filename)
  export = []
  File::open(filename, 'r') do |f|
  f.each_line do |line|
    data = line.gsub(/\r?\n/,'').scan(/"[^"]*["]|[^;,]+/)
    if data.length <= 2
      puts "Line has ONE or TWO columns"
      export.push({:link => data[0], :revision => data[1]})
    else
      puts "Line has MORE THAN TWO columns - skipping"
      next
    end
  end
  end
  puts export.inspect
  return export
end

def handle_files(list)

  #list.each_with_index do |(link,revision),index|
  list.each_with_index do |line,index|
   puts "Index: #{index} Line: #{line}"
  end











