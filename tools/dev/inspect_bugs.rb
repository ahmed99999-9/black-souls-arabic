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

# 1) Dump Battle Body Fix script properly
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
bb_idx = scripts.index{|a| a[1].include?("Battle Body")}
bb_code = Zlib::Inflate.inflate(scripts[bb_idx][2]) rescue scripts[bb_idx][2]
puts "==== Battle Body Fix (index #{bb_idx}) ===="
puts bb_code.force_encoding("UTF-8")[0, 15000]
puts "\n==== END BB Fix ====\n"

# 2) Check actual cat-scene picture usage: search CommonEvents for sequences that show pictures then erase
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
puts "CommonEvents count=#{arr.size}"
arr.each_with_index do |ce, idx|
  next unless ce
  has_pic = (ce.list||[]).any?{|c| c.code==231}
  has_fade = (ce.list||[]).any?{|c| c.code==221 || c.code==222}
  has_tint = (ce.list||[]).any?{|c| c.code==223}
  next unless has_pic || has_fade
  puts "\nCommonEvents[#{idx}] id=#{ce.id} name=#{ce.name.inspect} trigger=#{ce.trigger} switch=#{ce.switch_id}"
  puts "  has_pic=#{has_pic} has_fade=#{has_fade} has_tint=#{has_tint} total=#{ce.list.size}"
  # dump first 50 commands around pictures/fades
  ce.list.each_with_index do |cmd, ci|
    next unless [231,232,235,221,222,223,224,230,101,401,102,402,404,121,122,123,117,201,205].include?(cmd.code)
    puts "    [#{ci}] #{cmd.code} #{cmd.parameters.inspect[0,180]}"
  end
end

# 3) Check enemy page details for one specific map in depth
puts "\n\n==== Map002 enemy pages detailed ===="
obj = Marshal.load(File.binread("Data/Map002.rvdata2"))
obj.events.each do |id, ev|
  next unless ev && ev.pages && ev.pages[0].list.any?{|c| c.code==301}
  puts "\nEvent #{id} '#{ev.name}' at (#{ev.x},#{ev.y})"
  ev.pages.each_with_index do |pg, pi|
    puts " Page #{pi}: trigger=#{pg.trigger} cond_valid=#{pg.condition.self_switch_valid} ch=#{pg.condition.self_switch_ch.inspect} gfx=#{pg.graphic.character_name.inspect[0,40]}"
    puts "  list: #{pg.list.map{|c| c.code}.join(',')[0,200]}"
    pg.list.each_with_index do |cmd, ci|
      if cmd.code == 123
        puts "    [#{ci}] 123 SelfSwitch #{cmd.parameters.inspect}"
      elsif cmd.code == 205
        mr = cmd.parameters[1]
        puts "    [#{ci}] 205 MoveRoute this=#{cmd.parameters[0].inspect} wait=#{mr.wait} repeat=#{mr.repeat}" if mr
        if mr && mr.list
          mr.list.each do |mc|
            puts "        MC #{mc.code} #{mc.parameters.inspect[0,100]}"
          end
        end
      end
    end
  end
end
