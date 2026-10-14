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
def code(c); c.instance_variable_get(:@code) rescue nil; end
def params(c); c.instance_variable_get(:@parameters) rescue []; end
def indent(c); c.instance_variable_get(:@indent) rescue 0; end

obj = Marshal.load(File.binread("Data/Map002.rvdata2"))
events = obj.instance_variable_get(:@events) || {}
ev = events["11"]
name = ev.instance_variable_get(:@name).to_s.dup.force_encoding("UTF-8")
puts "event #{ev.instance_variable_get(:@id)} '#{name}' pages=#{ev.instance_variable_get(:@pages).size}"
(ev.instance_variable_get(:@pages)[0].instance_variable_get(:@list) || []).each do |cmd|
  c = code(cmd)
  puts "  indent=#{indent(c)} code=#{c} params=#{params(c).inspect[0, 50]}"
end
