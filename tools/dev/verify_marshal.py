# repo-root shim (repo cleanup): resolve relative paths to the project root.
import os as _os
if not _os.path.isdir("Data"):
    _os.chdir(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "..", ".."))
# Binary-level verification WITHOUT a full Marshal parser: 
# directly scan every Data/*.rvdata2 for known structural invariants.
# We avoid the Python Marshal parser entirely and just grep the raw bytes.

import re, glob, os, struct

# 1) Check: how many Maps actually fail to round-trip through Ruby Marshal dump/load?
# Use Ruby with a minimal Table stub that supports _dump/_load
ruby_code = r'''
# Minimal stubs so every Map file can be loaded
module RPG
  class Map
    class Encounter; end
  end
  class Event
    class Page
      class Condition; end
      class Graphic; end
    end
  end
  class MoveRoute; end
  class MoveCommand; end
  class EventCommand; end
  class AudioFile; end
  class BGM; end
  class BGS; end
  class MapInfo; end
end
class Table
  def self._load(s)
    # s is a string of packed ints: first 5 ints are dims + data
    # Just store raw bytes, we only need to verify load works
    o = allocate
    o.instance_variable_set(:@_raw, s)
    o
  end
  def _dump(lvl)
    @_raw || ""
  end
end

failed = []
ok = []
Dir.glob("Data/Map*.rvdata2").sort.each do |path|
  begin
    obj = Marshal.load(File.binread(path))
    # verify the object looks like a Map
    raise "not RPG::Map" unless obj.is_a?(RPG::Map) || obj.class.name =~ /Map/
    ok << File.basename(path)
  rescue Exception => e
    failed << [File.basename(path), e.class.to_s, e.message[0,120]]
    # print backtrace for first 2
    if failed.size <= 2
      STDERR.puts e.backtrace.first(3).join("\n")
    end
  end
end
puts "Marshal OK: #{ok.size}  FAIL: #{failed.size}"
failed.each {|f| puts " FAIL #{f[0]}: #{f[1]}: #{f[2]}" }
# Also test CommonEvents & Scripts
begin
  Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  puts "CommonEvents: OK"
rescue Exception => e
  puts "CommonEvents FAIL: #{e.class}: #{e.message[0,200]}"
end
begin
  Marshal.load(File.binread("Data/Scripts.rvdata2"))
  puts "Scripts: OK"
rescue Exception => e
  puts "Scripts FAIL: #{e.class}: #{e.message[0,200]}"
end
'''
open('/tmp/verify.rb','w',encoding='utf-8').write(ruby_code)
