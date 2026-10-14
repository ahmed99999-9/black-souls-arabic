#!/usr/bin/env ruby
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
# encoding: utf-8
class Table
  def self._load(s)
    o = allocate
    o.instance_variable_set(:@_raw, s)
    o
  end
  def _dump(l)
    @_raw || ""
  end
end
class Color
  def self._load(s)
    allocate
  end
  def _dump(l)
    ""
  end
end
class Tone
  def self._load(s)
    allocate
  end
  def _dump(l)
    ""
  end
end
module RPG
  class Map
    class Encounter
    end
  end
  class Event
    class Page
      class Condition
      end
      class Graphic
      end
    end
  end
  class MoveRoute
  end
  class MoveCommand
  end
  class EventCommand
  end
  class CommonEvent
  end
  class System
  end
  class Troop
    class Page
    end
    class Member
    end
  end
  class Actor
  end
  class Class
  end
  class Skill
  end
  class Item
  end
  class Weapon
  end
  class Armor
  end
  class Enemy
  end
  class State
  end
  class Animation
  end
  class Tileset
  end
  class AudioFile
  end
  class BGM
  end
  class BGS
  end
  class SE
  end
  class ME
  end
  class MapInfo
  end
end
require 'zlib'

data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
puts "Total scripts #{scripts.size}"

puts "\n=== All titles ==="
scripts.each_with_index do |e, i|
  t = e[1].to_s
  t = t.dup.force_encoding("UTF-8")
  t = t.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  puts "#{i.to_s.rjust(3)}: #{t.inspect} (id #{e[0]}) zlen #{e[2].bytesize}"
end

puts "\n=== Custom scripts full dump ==="
scripts.each_with_index do |entry, i|
  title = entry[1].to_s.dup.force_encoding("UTF-8")
  low = title.downcase
  interesting = low.include?("arabic") || low.include?("reshap") || low.include?("battle") ||
                low.include?("body") || low.include?("window") || low.include?("cache") ||
                low.include?("message")
  next unless interesting
  content = begin
    Zlib::Inflate.inflate(entry[2])
  rescue StandardError
    entry[2]
  end
  content = content.to_s.dup.force_encoding("UTF-8")
  content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  puts "\n\n======== SCRIPT #{i} id=#{entry[0]} title=#{title.inspect} len=#{content.length} ========"
  puts content[0, 20000]
  puts "======== END #{i} ========"
end
