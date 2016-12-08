Description
===========
This is temporary repository for SVN checkout script.
Not intended for any practical purposes but to demonstrate a way to make a checkout from legacy VCS and do other things.

Requirements
============
Ruby version 2.1+ and 'sqlite3' gem
Zip 3.0+
Subversion 1.9+

Gems
====
These gems are required:

- 'logger'
- 'uri'
- 'json'
- 'fileutils'
- 'open3'
- 'sqlite3' (may require installation)

Most of them are present in standard Ruby installation.

**Note:** you can run `first_run_check.sh` to make sure everything is installed. 

Usage
=====
~~~
$ ruby ./script.rb <repo-list-file(s)>
~~~
Or make this script executable by running `chmod +x script.rb`.

Repository list file format is:
~~~
<http(s) address of SVN repository>;<revision or null>
~~~
Please make sure file 'config.json' exists before first run.

Options
=======
Use `-s` to write all log entries to standard output instead of log file.
