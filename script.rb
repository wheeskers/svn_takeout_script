#!/usr/bin/ruby

require 'logger'
require 'uri'
require 'json'
require 'fileutils'
require 'open3'

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

  #create export directory if it does not exist yet
  FileUtils::mkdir_p($config['export']['directory']) unless File.directory?($config['export']['directory'])


  list.each_with_index do |line,index|
    puts "Index: #{index} Line: #{line}"
    repo_name_fingerprint = URI::parse(line[:link]).path.to_s.gsub(/\/|_|\./,'-').match(/\w.*\w/)

    revision = line[:revision]
    repolink = line[:link]

    # Basic SVN checkout
    cmd_line = [ "svn", "checkout", "#{repolink}", "#{$config['export']['directory']}/#{repo_name_fingerprint}" ]

    # Use empty checkout if this is enabled in config
    cmd_line.insert(2, "--depth=empty") if $config['empty_checkout']

    # Use specific revision if it is specified
    cmd_line.insert(2, "-r#{revision}") if revision.to_s.match(/\d+/)

    #puts cmd_line.join(' ') ; next

    svn_checkout_exit_status = nil
    svn_resulting_revision   = nil

    Open3::popen3( *cmd_line ) do |stdin, stdout, stderr, wait_thr|
      pid = wait_thr.pid
      sta = wait_thr.value.exitstatus
      out = stdout.read
      #puts "Subprocess stdout: #{out} Exit status: #{sta} stderr: #{stderr.read}"
      svn_checkout_exit_status = wait_thr.value.exitstatus
      svn_resulting_revision = out.gsub(/\r?\n/,'').match(/(?<=Checked out revision )\d+/)
    end

    puts svn_checkout_exit_status
    puts svn_resulting_revision

    zip_exit_status = nil

    if svn_checkout_exit_status == 0
        cmd_line_1 = [ "zip", "-r", "#{$config['export']['directory']}#{repo_name_fingerprint}-files-r#{svn_resulting_revision}.zip", "#{$config['export']['directory']}#{repo_name_fingerprint}" ]
        puts cmd_line_1.join(' ')
        Open3::popen3( *cmd_line_1 ) do |stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid
          sta = wait_thr.value.exitstatus
          zip_exit_status = wait_thr.value.exitstatus
        end
    else
       puts "SVN returned error, do nothing..."
    end

    if zip_exit_status == 0
      puts "Remove #{$config['export']['directory']}#{repo_name_fingerprint}"
      FileUtils::rm_r("#{$config['export']['directory']}#{repo_name_fingerprint}")
      
    else
      puts "Zip returned error, do nothing"
    end
  end

end

tmp_repo_list = parse_in_file ARGV[0]
handle_files tmp_repo_list
