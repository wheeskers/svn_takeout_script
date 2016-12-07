#!/usr/bin/ruby

require 'sqlite3'

DBNAME = 'db.sqlite'

def create_new_db(dbfilename)
  SQLite3::Database::new( dbfilename ) do |db|
    db.execute('CREATE TABLE event_log (id INTEGER PRIMARY KEY AUTOINCREMENT, stamp TEXT, event TEXT, result TEXT, details TEXT, files TEXT);')
    db.execute("INSERT INTO event_log (stamp, event,result,details,files) VALUES (CURRENT_TIMESTAMP, 'Database created', '0', 'New sqlite3 file', '#{dbfilename}' )")
  end
end
