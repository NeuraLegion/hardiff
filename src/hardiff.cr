require "har"
require "option_parser"

module Hardiff
  VERSION = "0.1.0"
end

options = Hash(String, String).new

parser = OptionParser.parse do |parser|
  parser.banner = "Usage: hardiff [arguments]"
  parser.on("-b PATH", "--base-har PATH", "Path to the base HAR file") { |path| options["base"] = path }
  parser.on("-n PATH", "--new-har PATH", "Path to the new HAR file") { |path| options["new"] = path }
  parser.on("-o PATH", "--output PATH", "Path to save the generated diff HAR file") { |path| options["output"] = path }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
  if ARGV.empty?
    STDERR.puts parser
    exit(1)
  end
end

unless options["base"]? && options["new"]? && options["output"]?
  STDERR.puts "ERROR: Missing required arguments."
  STDERR.puts parser
  exit(1)
end

# Make sure all the har files exits
unless File.exists?(options["base"])
  STDERR.puts "ERROR: #{options["base"]} does not exist."
  exit(1)
end
unless File.exists?(options["new"])
  STDERR.puts "ERROR: #{options["new"]} does not exist."
  exit(1)
end

# Parse the HAR files and raise an error if they are invalid
begin
  base_har = HAR.from_file(options["base"])
  puts "Base HAR file contains #{base_har.entries.size} entries."
rescue e : JSON::ParseException
  STDERR.puts "ERROR: #{options["base"]} is not a valid HAR file: #{e.message}"
  exit(1)
end

begin
  new_har = HAR.from_file(options["new"])
  puts "New HAR file contains #{new_har.entries.size} entries."
rescue e : JSON::ParseException
  STDERR.puts "ERROR: #{options["new"]} is not a valid HAR file: #{e.message}"
  exit(1)
end

# Initialize the diff HAR file
diff_har = HAR::Data.new(
  log: HAR::Log.new(
    version: "1.2",
    creator: HAR::Creator.new(name: "hardiff", version: Hardiff::VERSION),
  )
)

# Find new entries which are in the new HAR file but not in the base HAR file
new_har.entries.each do |new_entry|
  unless base_har.entries.any? { |base_entry| (base_entry.request.url == new_entry.request.url) && (base_entry.request.method == new_entry.request.method) && (base_entry.request.post_data == new_entry.request.post_data) }
    diff_har.log.entries << new_entry
  end
end

puts "New HAR file contains #{diff_har.log.entries.size} new entries."

# Save the new HAR file to the output path
File.write(options["output"], diff_har.to_json)
