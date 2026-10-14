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
require 'zlib'
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
wanted = ["Arabic Reshaper", "Arabic Fix 7", "Arabic Fix 8", "Window Title Fix", "Battle Body Fix 5"]
scripts.each_with_index do |(id, title, code), i|
  next unless wanted.any?{|w| title.include?(w)}
  dec = Zlib::Inflate.inflate(code) rescue code
  dec = dec.force_encoding("UTF-8")
  puts "="*80
  puts "INDEX #{i} ID=#{id} TITLE=#{title.inspect}"
  puts "="*80
  puts dec
  puts "\n"
end
