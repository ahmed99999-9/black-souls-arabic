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
obj = Marshal.load(File.binread("Data/Map002.rvdata2"))
ev = obj.instance_variable_get(:@events).values.find do |e|
  (e.instance_variable_get(:@name).to_s.force_encoding("UTF-8") =~ /\u6575/) &&
    (e.instance_variable_get(:@pages) || []).size >= 3
end
raise "not found" unless ev
name = ev.instance_variable_get(:@name).to_s.force_encoding("UTF-8")
puts "event '#{name}' pages=#{ev.instance_variable_get(:@pages).size}"
ev.instance_variable_get(:@pages).each_with_index do |pg, pi|
  puts "pg#{pi} trig=#{pg.instance_variable_get(:@trigger)}"
  (pg.instance_variable_get(:@list) || []).each do |cmd|
    c = code(cmd)
    p = params(cmd)
    if c == 205
      mr = p[1]
      steps = (mr.instance_variable_get(:@list) rescue []).map { |mc| "#{code(mc)}:#{params(mc).inspect}" }
      puts "  [205] wait=#{(mr.instance_variable_get(:@wait) rescue nil)} repeat=#{(mr.instance_variable_get(:@repeat) rescue nil)} steps=#{steps.join(' | ')}"
    else
      puts "  [#{c}] #{p.inspect[0, 60]}"
    end
  end
end
