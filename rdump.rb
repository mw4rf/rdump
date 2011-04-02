#!/usr/bin/ruby
###############################################################################
# Licence
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# About
#
#     rdump.rb
#     version 0.1 (01 Apr. 2011)
#
#     This is a simple Ruby script to DUMP a PostgreSQL database in a GZ
#     compressed file.
#
# How tu RUN the script
#
#     You need:
#       1) A Ruby 1.8 or 1.9 environment
#       2) A PostgreSQL 8+ database
#
#       The PostgreSQL 'bin' directory MUST be in your path.
#       Meaning, you should be able to type "psql" in a terminal and get no error message.
#
#       The scripts connects to PostgreSQL as "postgres".
#       This is the default admin user created by PostgreSQL.
#       Make sure this user is available and has all the rights to dump.
#
#       3) Give the script the right to be executed:
#         chmod +x rdump.rb
#
#       And then, run it like that:
#         ./rdump.rb
#
#       or, if you can't chmod:
#         ruby rdump.rb
#
# How to USE the script
#
#     It can be executed in a terminal, or as a cronjob.
#
#     To execute it as a cronjob, you'll have to supply some mandatory arguments:
#       1) the database name (--database [name]), or use --all-databases
#       2) the type of dump (--dump [FULL|SCHEMA|DATA]). FULL means Schema+Data.
#       3) the directory where to save the dump file (--to [Unix Path, eg. ~/backups/])
#
#     To execute it yourself, in a terminal, either use some arguments (type [./rdump --help] for a list)
#     or just run it without any argument, and you will be asked to choose the database name, the dump type
#     and the dumpfile path.
#
#     If you don't answer a question, the default value will be used:
#       no database name = backup all the databases
#       no dump type specified = FULL dump (schema+data)
#       no path specified = write the file in the current directory, if it's writable
#         (NB: the current directory is the directory where you run the script from, not the script's directory
#           eg. if you're in ~/home/ and the script in ~/scripts/, the current directory is ~/home/)
#
# One More Thing
#
#   This script is not perfect. It's far from it. However, it shouldn't do any harm.
#   But that's not a reason to be too confident: you should NEVER run a script
#   if you don't understand what it does. Take 5 minutes, and read the code.
#   If you can't read/understand the source code, search for dangerous commands
#   such as "rm". Finally, never run a script as root (su/sudo) unless you can't
#   run it as a normal user.
#
###############################################################################

require 'optparse'

# TODO
# create directory if no exist, in interactive mode

########## COLOR OUTPUT Functions
def blue    (str, tg=:fg)  if tg == :bg then return "\e[44m#{str}\e[49m" else return "\e[34m#{str}\e[0m" end end
def red     (str, tg=:fg)  if tg == :bg then return "\e[41m#{str}\e[49m" else return "\e[31m#{str}\e[0m" end end
def green   (str, tg=:fg)  if tg == :bg then return "\e[42m#{str}\e[49m" else return "\e[32m#{str}\e[0m" end end
def yellow  (str, tg=:fg)  if tg == :bg then return "\e[43m#{str}\e[49m" else return "\e[33m#{str}\e[0m" end end

def yellowbg(str) return yellow(str,:bg) end

def b(str) return "\e[1m#{str}\e[22m" end
def i(str) return "\e[3m#{str}\e[23m" end

###############################################################################
########## Command line options
###############################################################################

options = {}
opts = OptionParser.new do |opt|
  opt.banner = <<-eos
#{blue "Usage: rdump.rb [options]"}
  
#{b "Install"}
  1) Give rights to execute:
      chmod +x rdump.rb
  2) Run it like that:
      ./rdump
      
  or, if you can't chmod:
      ruby rdump.rb

#{b "Call the script as a cronjob"}
If you call this script as a cronjob, you #{red b "MUST"} provide all mandatory options:
  1) --all-databases #{b "OR"} --database [name]
  2) --full-dump  #{b "OR"} --dump [FULL|SCHEMA|DATA]
  3) --here #{b "OR"} --to [UNIX path to a writable directory]

#{b "Call the script manually"}
If you call this script yourself (i.e. not as a cronjob), you don't have to provide all the options.
If an option is omitted, you will be asked to provide a custom value, or just hit #{b "RETURN"} to use the default value.

#{b "Exemples"}
  # Dump all databases, each one in its own file,
  # and saves thoses files in the current directory.
  # You will be asked for the dump type (FULL, SCHEMA, DATA).
  ./rdump --all-databases --here

  # Dump the structure and the data of all the databases,
  # in one single file, saved in ~/backups/my_databases/
  ./rdump --all-databases --in-one-file --full-dump --to ~/backups/my_databases/

  # Dumps the Schema of MyBase database and saves
  # the file in the current directory.
  ./rdump --database MyBase --dump SCHEMA --here

  # The most complete cronjob would be:
  ./rdump --full-dump --all-databases --in-one-file --to ~/pgbackups

#{b "Available options"}:
eos

  # Database name
  options[:database] = nil
  opt.on "-b", "--database DB", "The name of the database to dump (actually, the name of the schema)" do |b|
    options[:database] = b
  end

  # Dump all databases ?
  options[:all] = false
  opt.on "-a", "--all-databases", "Dump all databases" do |a|
    options[:all] = a
  end

  # Dump all databases IN ONE FILE ?
  options[:in_one_file] = false
  opt.on "-i", "--in-one-file", "When used with --all-databases, dumps'em all in ONE SINGLE file" do |i|
    options[:in_one_file] = i
  end

  # Dump type
  options[:dumptype] = nil
  opt.on "-d", "--dump TYPE", "What should we dump? Options are: the [FULL] database (default), its [SCHEMA] or the [DATA] only" do |t|
    if t == "FULL"
      options[:dumptype] = "FULL"
    elsif t == "DATA"
      options[:dumptype] = "DATA"
    elsif t = "SCHEMA"
      options[:dumptype] = "SCHEMA"
    end
  end

  # Full dump (default)
  opt.on "-f", "--full-dump", "Full dump (same as --dump FULL)" do |f|
    options[:dumptype] = "FULL"
  end

  # File destination
  options[:to] = nil
  opt.on "-t", "--to PATH", "Output file path (Unix format). Default is the current directory (from where the script is executed)" do |t|
    if Dumper.check_dir t
      options[:to] = t
    end
  end

  # File destination is HERE (script directory)
  opt.on "-h", "--here", "Path is here, the script's path." do |h|
    options[:to] = ""
  end

  # Verbose
  options[:v] = false # default
  opt.on "-v", "--verbose", "(very) Verbose output" do |v|
    options[:v] = true
  end

end.parse!

if options[:v]
  puts "Database to dump: #{green b options[:database]}"
  puts "Dump type: #{green b options[:dumptype]}"
  puts "Destination: #{green b options[:to]}"
end

###############################################################################
########## Runtime (with interactive mode)
###############################################################################

# Select the database to use
if options[:database].nil? and !options[:all]
  puts " "
  puts b "Please input the NAME of your database (mandatory):"
  options[:database] = gets.chomp
  if options[:database].empty?
    puts blue "No database selected. Dumping all databases."
    options[:all] = true
  else
    puts "Database selected : #{green b options[:database]}"
  end
end

# Select what to do
if options[:dumptype].nil?
  puts " "
  puts b "Please select one of the following options [1|2|3] (default: FULL): "
  puts b "  1) FULL"
  puts b "  2) SCHEMA"
  puts b "  3) DATA"
  dumptype = gets.chomp
  if    dumptype == "1" or dumptype == "FULL" or dumptype == "full"
    options[:dumptype] = "FULL"
  elsif dumptype == "2" or dumptype == "SCHEMA" or dumptype == "schema"
    options[:dumptype] = "SCHEMA"
  elsif dumptype == "3" or dumptype == "DATA" or dumptype == "data"
    options[:dumptype] = "DATA"
  else
    puts blue "Using default option"
    options[:dumptype] = "FULL"
  end
  puts "Option selected: #{green b options[:dumptype]}"
end

# Where to save the file ?
if options[:to].nil?
  puts " "
  puts b i "Please input the destination path of the dump (default: current directory): "
  options[:to] = gets.chomp
  if options[:to].empty?
    puts blue "Using default path"
    options[:to] = ""
    puts "Path selected: #{green b Dir.pwd}"
  else
    puts "Path selected: #{green b options[:to]}"
  end
end

puts " "

###############################################################################
########## PostgreSQL DUMP Functions
###############################################################################
class Dumper

  attr_accessor :database, :dumptype, :dumptype_param, :to, :verbose, :verbose_param, :file

  def initialize(options_hash)
    @database = options_hash[:database]
    @dumptype = options_hash[:dumptype]
    @to = options_hash[:to]
    @verbose = options_hash[:v]

    # FULL, SCHEMA, DATA
    if @dumptype == "FULL"
      @dumptype_param = ""
    elsif @dumptype == "SCHEMA"
      @dumptype_param = "-s"
    elsif @dumptype == "DATA"
      @dumptype_param = "-a"
    end

    # VERBOSE?
    if @verbose
      @verbose_param = "-v"
    else
      @verbose_param = ""
    end

  end

  # DUMP
  # the {database} database
  # with the {dumptype} option : FULL dump, SCHEMA dump or DATA dump
  # {to} the path
  # and with a {v[erbose]} output
  def dump

    # DESTINATION
    @time = Time.now.strftime("%Y-%m-%d-%H%M%S")
    @file = "#{@to}#{@database}_#{@dumptype}_#{@time}.sql.gz"

    # Build the command
    q = "pg_dump #{@dumptype_param} #{@verbose_param} -U postgres #{@database} | gzip #{@verbose_param} --best > #{@file}"

    if @verbose
      puts "Running: #{blue b q}"
    end

    # Execute the command
    res = %x{#{q}}

    unless res.empty?
      puts yellowbg red b "Something went wrong :"
      if v
        puts yellowbg res
      end
    else
      puts "Dumped #{green b @database} in #{green b @file}"
    end
  end

  # DUMP_ALL
  # Dump'em all !
  def dump_all_in_one_file

    # DESTINATION
    @time = Time.now.strftime("%Y-%m-%d-%H%M%S")
    @file = "#{@to}ALL_DATABASES_#{@dumptype}_#{@time}.sql.gz"

    # Build the command
    q = "pg_dumpall #{@dumptype_param} #{@verbose_param} -U postgres | gzip #{@verbose_param} --best > #{@file}"

    if @verbose
      puts "Running: #{blue b q}"
    end

    # Execute the command
    res = %x{#{q}}

    unless res.empty?
      puts yellowbg red b "Something went wrong :"
      if v
        puts yellowbg res
      end
    else
      puts "Dumped #{green b "all databases"} in #{green b @file}"
    end
  end

  # Dump'em all
  # each one in its own file
  def dump_all
    query = "select datname from pg_database where not datistemplate and datallowconn;"
    run = %x{psql -U postgres -At -c "#{query}" postgres}
    # String.each_line DOES NOT remote the '\n', whereas File.open(f).each does. This should be fixed in Ruby core!
    # Chomp removes ONLY ONE endline character (either \r or \n), so if we have "\r\n", we'll end up with "\r"
    # PostgreSQL uses a single "\n", but that could change, we never know...
    run.each_line do |database|
      @database = database.chomp.chomp
      self.dump
    end
  end

  # Check if the given file is an existing, writable directory
  # And not, and if possible, create it
  def self.check_dir t
    if not File.exists?(t)
      puts "#{t} does not exist. We'll try to create it, but it'll fail if you don't have the required permissions."
      %x{mkdir -p #{t}}
      if File.directory?(t) and File.writable?(t)
        puts green "Directory successfully created."
        return true
      else
        puts red "Could not create that directory."
        return false
      end
    elsif not File.directory?(t)
      puts red "#{t} is not a valid directory."
      return false
    elsif not File.writable?(t)
      puts red "#{t} is not writable, you should run this script as root, chmod this directory, of choose another directory."
      return false
    else
      return true
    end
  end

end #class

###############################################################################
########## Do the job !
###############################################################################
dumper = Dumper.new(options)
if options[:all]
  if options[:in_one_file]
    dumper.dump_all_in_one_file
  else
    dumper.dump_all
  end
else
  dumper.dump
end


########## The end
puts blue b "Bye!"




