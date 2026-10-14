# encoding: utf-8
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
class Table
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
class Color
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
class Tone
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
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
  class CommonEvent; end
  class System; end
  class Troop
    class Page; end
    class Member; end
  end
  class Actor; end
  class Class; end
  class Skill; end
  class Item; end
  class Weapon; end
  class Armor; end
  class Enemy; end
  class State; end
  class Animation; end
  class Tileset; end
  class AudioFile; end
  class BGM; end
  class BGS; end
  class SE; end
  class ME; end
  class MapInfo; end
end

files = Dir["Data/*.rvdata2"].sort
files.each do |f|
  begin
    obj = Marshal.load(File.binread(f))
  rescue => e
    puts "#{f}: LOAD FAIL #{e.class}: #{e.message[0, 80]}"
    next
  end
  # top-level hash?
  if obj.is_a?(Hash)
    keys = obj.keys
    non_int = keys.reject { |k| k.is_a?(Integer) }
    if non_int.any?
      puts "#{f}: TOP-LEVEL HASH with non-integer keys: #{non_int.first(5).map { |k| "#{k.inspect}(#{k.class})" }.join(', ')} total=#{keys.size}"
    else
      puts "#{f}: top-level Hash int keys ok (#{keys.size})"
    end
  else
    puts "#{f}: #{obj.class}"
  end
end

puts
puts "=== Map events hash key types ==="
str_keyed = 0
Dir["Data/Map*.rvdata2"].sort.each do |f|
  obj = Marshal.load(File.binread(f))
  ev = obj.instance_variable_get(:@events) rescue nil
  next unless ev
  types = ev.keys.map(&:class).uniq
  unless types == [Integer]
    str_keyed += 1
    puts "  #{f}: keys=#{types.inspect}"
  end
end
puts "maps with non-integer event keys: #{str_keyed}"

puts
puts "=== MapInfos ==="
begin
  infos = Marshal.load(File.binread("Data/MapInfos.rvdata2"))
  keys = infos.keys
  puts "  keys=#{keys.first(5).map { |k| "#{k.inspect}(#{k.class})" }.join(', ')} total=#{keys.size}"
  non_int = keys.reject { |k| k.is_a?(Integer) }
  puts "  non-integer keys: #{non_int.size}"
rescue => e
  puts "  MapInfos fail: #{e}"
end
