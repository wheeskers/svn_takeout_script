#!/usr/bin/ruby

require 'logger'
require 'uri'
require 'json'
require 'fileutils'
require 'open3'
require 'sqlite3'

begin
  $config = JSON::parse(File.read("config.json"))
rescue
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [FATAL] Incorrect JSON file or 'config.json' does not exist!"
  exit 1
end

unless ARGV.any?{|arg|arg.match(/-s/)}
  $log = Logger::new("#{$config['log']['file']}")
else
  $log = Logger::new(STDOUT)
end

$log.level          = eval "Logger::#{$config['log']['level']}"
$log.progname       = 'SubversionCheckoutScript'
$log.formatter      = proc { |severity, datetime, progname, msg| "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n" }
$log.info{ "Starting, log ready." }

# Create new db object
begin
  $db = SQLite3::Database::new( $config['database'] )
  $db.execute('CREATE TABLE IF NOT EXISTS event_log (id INTEGER PRIMARY KEY AUTOINCREMENT, stamp TEXT, event TEXT, result TEXT, details TEXT, files TEXT);')
rescue Exception => e
  $log.fatal{ "Something is wrong with sqlite3 db file or sqlite3 itself. Exception is: #{e}" }
  exit 2
end

# DB store event method
def store_event(db,n_event,n_result,n_details,n_files)
  db.execute("INSERT INTO event_log (stamp, event,result,details,files) VALUES (datetime(CURRENT_TIMESTAMP,'localtime'),'#{n_event}','#{n_result}','#{n_details}','#{n_files}');")
end

# Create an array with files to work with
files = []
ARGV.select{|arg|arg.match(/^[^\-]+/)}.each do |arg|
  if File::exist?(arg)
    $log.info{ "File '#{arg}' exists and will be parsed" }
    files.push arg
  else
    $log.info{ "File '#{arg}' does not exist and will be skipped" }
  end
end

# Check if there are no valid files to work with
if files.empty?
  $log.error{ "No valid filenames passed as arguments, exiting now..." }
  exit 1
else
  $log.info{ "Input ready, starting working with file(s)" }
  $log.debug{ "Input file list: #{files.inspect}" }
end

# Parse file into a Hash (we need to have distinct repo address and version)
def parse_in_file(filename)
  $log.info{ "Working with file: '#{filename}'" }
  export = []
  File::open(filename, 'r') do |f|
    f.each_line do |line|
      data = line.gsub(/\r?\n/,'').scan(/"[^"]*["]|[^;,]+/)
      if data.length <= 2
        $log.debug{ "Success: line '#{line.chomp}' has one or two columns" }
        export.push({:link => data[0], :revision => data[1]})
      else
        $log.error{ "Line '#{line.chomp}' has more than 2 columns - skipping..." }
        next
      end
    end
  end
  $log.debug { "Data to process extracted from raw lines: #{export.inspect}" }
  return export
end

def handle_files(list)
  # Create export directory if it does not exist yet
  FileUtils::mkdir_p($config['export']['directory']) unless File.directory?($config['export']['directory'])

  # Process each repo and revision from Hash
  list.each_with_index do |line,index|
    # Check if URI is correct
    begin
      link = URI::parse(line[:link])
    rescue Exception => e
      $log.error{ "Unable to parse repo URL: #{e}" }
      next
    end
    # Check if URI is URL and uses HTTP or HTTPS
    if link.kind_of?(URI::HTTPS) || link.kind_of?(URI::HTTP)
      $log.info{ "Link accepted as correct: #{link}" }
    else
      $log.info{ "Skipping broken link - check format manually: #{link}" }
      next
    end
    # Create 'package' name based on repo location
    repo_name_fingerprint = URI::parse(line[:link]).path.to_s.gsub(/\/|_|\./,'-').match(/\w.*\w/)
    $log.info "Using repo name part as package name --> #{repo_name_fingerprint}"
    revision = line[:revision]
    repolink = line[:link]
    tmp_checkout_dir = "#{$config['export']['directory']}#{repo_name_fingerprint}"
    # Basic SVN checkout
    cmd_line = [ "svn", "checkout", "#{repolink}", tmp_checkout_dir ]
    # Use empty checkout if this is enabled in config
    cmd_line.insert(2, "--depth=empty") if $config['empty_checkout']
    # Use specific revision if it is specified
    cmd_line.insert(2, "-r#{revision}") if revision.to_s.match(/\d+/)
    $log.debug{ "Subversion command line is: '#{cmd_line.join(' ')}'" }

    svn_checkout_pid         = nil
    svn_checkout_exit_status = nil
    svn_resulting_revision   = nil

    # Run Subversion from system shell as separate process
    Open3::popen3( *cmd_line ) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      svn_checkout_pid = wait_thr.pid
      stdout.each_line { |line| svn_resulting_revision = line.match(/(?<=Checked out revision )\d+/) }
      svn_checkout_exit_status = wait_thr.value.exitstatus
    end

    $log.info{ "Subversion process exit status: #{svn_checkout_exit_status} Checked out revision: #{svn_resulting_revision}" }

    zip_exit_status   = nil
    zip_exit_lastline = nil

    # Run zip archiver if Subversion process is successfull
    if svn_checkout_exit_status == 0
        # Only top directories are listed, use "/**/*" for more inclusive listing
        tcd_files = Dir::glob(tmp_checkout_dir+"/*")
        store_event($db,'Succesfull checkout',"#{svn_checkout_exit_status}","Revision #{svn_resulting_revision}","#{tcd_files.join(',')}")
        cmd_line_1 = [ "zip", "-r", "#{tmp_checkout_dir}-files-r#{svn_resulting_revision}.zip", tmp_checkout_dir ]
        $log.debug{ "Zip command line is: #{cmd_line_1.join(' ')}" }
        Open3::popen3( *cmd_line_1 ) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          stdout.each_line{|line|}
          pid = wait_thr.pid
          zip_exit_status = wait_thr.value.exitstatus
        end
    else
       $log.error{ "Subversion error, do nothing..." }
       store_event($db,'Checkout failed',"#{svn_checkout_exit_status}",'Subversion process error!','---')
    end

    # Remove temporary working directory if files are packed in zip archive
    if zip_exit_status == 0
      store_event($db,'Files files are successfully packed (zip acrhiver success)','0',"Tail line: #{zip_exit_lastline}","#{tmp_checkout_dir}-files-r#{svn_resulting_revision}.zip")
      $log.debug{ "Removing temporary working directory '#{tmp_checkout_dir}'" }
      FileUtils::rm_r(tmp_checkout_dir) if File::directory?(tmp_checkout_dir)
    else
      $log.error{ "Zip returned error, do nothing..." }
      store_event($db,'Files are NOT packed, zip error',"#{zip_exit_status}","Tail line: #{zip_exit_lastline}",'--')
    end
  end
end

# Calling to methods
files.each do |f|
  $log.info{ "Extraction repository data from file '#{f}'" }
  tmp_repo_list = parse_in_file f
  $log.debug{ "Extracted data: #{tmp_repo_list.inspect}" }
  handle_files tmp_repo_list
end

