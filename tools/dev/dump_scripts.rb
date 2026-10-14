#!/usr/bin/env ruby
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
# encoding: utf-8
class Table; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; end
class Color; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
class Tone; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
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
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
puts "scripts count=#{scripts.size}"
scripts.each_with_index do |(id, title, code), idx|
  dec = Zlib::Inflate.inflate(code) rescue code
  puts "#{idx}: id=#{id} title=#{title.inspect} dec_len=#{dec.bytesize}"
end
idx = scripts.index{|a| a[1].include?("Battle Body")}
puts "Battle Body idx=#{idx.inspect}"
if idx
  dec = Zlib::Inflate.inflate(scripts[idx][2]) rescue scripts[idx][2]
  puts dec.force_encoding('UTF-8')[0,12000]
end
