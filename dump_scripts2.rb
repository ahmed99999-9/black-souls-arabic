#!/usr/bin/env ruby
# encoding: utf-8
class Table; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; end
class Color; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
class Tone; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
module RPG
  class Map; class Encounter; end; end
  class Event; class Page; class Condition; end; class Graphic; end; end
  class MoveRoute; end
  class MoveCommand; end
  class EventCommand; end
  class CommonEvent; end
  class System; end
  class Troop; class Page; end; class Member; end; end
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
puts "Total scripts #{scripts.size}"
scripts.each_with_index do |entry, i|
  id = entry[0]
  title = entry[1]
  compressed = entry[2]
  # content is zlib deflated UTF-8
  begin
    content = Zlib::Inflate.inflate(compressed)
  rescue
    content = compressed
  end
  content = content.force_encoding("UTF-8") rescue content
  # preview
  if title.downcase.include?("arabic") || title.downcase.include?("reshap") || title.downcase.include?("battle") || title.downcase.include?("body") || title.downcase.include?("message") || title.downcase.include?("window") || title.include?("عربي")
    puts "\n=== SCRIPT #{i} id=#{id} title=#{title.inspect} len=#{content.length} ==="
    puts content[0,8000]
    puts "\n=== END ==="
  end
end
# also dump titles list
puts "\n=== All titles ==="
scripts.each_with_index do |e,i|
  puts "#{i.to_s.rjust(3)}: #{e[1].inspect} (id #{e[0]}) len #{e[2].bytesize}"
end
