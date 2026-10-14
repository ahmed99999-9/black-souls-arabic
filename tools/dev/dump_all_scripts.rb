# encoding: utf-8
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
require "zlib"
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
FileUtils.rm_rf("/tmp/allscripts") if defined?(FileUtils)
Dir.mkdir("/tmp/allscripts") unless Dir.exist?("/tmp/allscripts")
scripts.each_with_index do |(id, title, code), idx|
  dec = Zlib::Inflate.inflate(code) rescue code
  fname = "/tmp/allscripts/#{idx.to_s.rjust(3, "0")}.rb"
  File.binwrite(fname, dec.force_encoding("UTF-8"))
end
puts "wrote #{scripts.size} scripts"
