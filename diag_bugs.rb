#!/usr/bin/env ruby
# encoding: utf-8
class Table; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; end
class Color; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
class Tone; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; def initialize(*a); end; end
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
require 'find'

# ---- 1. Pictures inventory vs ShowPicture refs ----
pics_on_disk = Dir["Graphics/Pictures/*"].map{|p| File.basename(p.downcase) rescue p}
# also check Bonus folder?
pics_on_disk += Dir["Bonus/**/*"].map{|p| File.basename(p.downcase) rescue p}
pics_set = pics_on_disk.map(&:downcase).uniq
puts "Pictures on disk count=#{pics_set.size}"
puts pics_set.first(20).join(", ")

# Collect showPicture refs from Maps + CommonEvents + Troops
refs = {}
def collect_event_list(list, refs)
  return unless list
  list.each do |cmd|
    next unless cmd
    if cmd.code == 231 # Show Picture
      pic = cmd.parameters[1].to_s rescue ""
      refs[pic] ||= 0
      refs[pic] += 1
    elsif cmd.code == 232 # Move Picture
      pic = cmd.parameters[1].to_s rescue ""
      refs[pic] ||= 0
      refs[pic] += 1 if pic && !pic.empty?
    end
  end
end

# Maps
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  begin
    obj = Marshal.load(File.binread(fname))
    next unless obj && obj.events
    obj.events.each do |id, ev|
      next unless ev && ev.pages
      ev.pages.each do |pg|
        collect_event_list(pg.list, refs)
        # also check moves?
        pg.list.each do |cmd|
          if cmd.code == 209 # Set Move Route
            # move route may contain change graphic etc not picture
          end
        end
      end
    end
  rescue => e
    puts "Map load error #{fname}: #{e}"
  end
end

# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each do |ce|
    next unless ce && ce.list
    collect_event_list(ce.list, refs)
  end
  puts "CommonEvents count=#{arr.compact.size}"
rescue => e
  puts "CommonEvents error #{e}"
end

# Troops
begin
  troops = Marshal.load(File.binread("Data/Troops.rvdata2"))
  troops.each do |t|
    next unless t && t.pages
    t.pages.each do |pg|
      collect_event_list(pg.list, refs) if pg.list
    end
  end
  puts "Troops count=#{troops.compact.size}"
rescue => e
  puts "Troops error #{e}"
end

puts "\n=== ShowPicture refs (unique #{refs.size}) ==="
refs.sort_by{|k,v| -v}.each do |pic, cnt|
  # resolve existence: check if file exists with extension .png?
  found = pics_set.any?{|f| f == pic.downcase || f == (pic.downcase + ".png") || f.start_with?(pic.downcase) }
  # more precise: check Graphics/Pictures/pic.png
  disk_exists = File.exist?("Graphics/Pictures/#{pic}.png") || File.exist?("Graphics/Pictures/#{pic}") || Dir["Graphics/Pictures/#{pic}.*"].any?
  status = disk_exists ? "OK" : "MISSING"
  puts "  #{status} pic=#{pic.inspect} count=#{cnt}"
end

# Report missing only
missing = refs.keys.select{|pic| !(File.exist?("Graphics/Pictures/#{pic}.png") || File.exist?("Graphics/Pictures/#{pic}") || Dir["Graphics/Pictures/#{pic}.*"].any?) && !pic.empty?}
puts "\nMISSING pictures: #{missing.size}"
missing.each{|m| puts "  #{m.inspect}" }

puts "\n\n=== Tint/Fade/Flash analysis on maps ==="
# Look for maps with heavy tint/fade that may leave screen black
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  obj = Marshal.load(File.binread(fname))
  next unless obj && obj.events
  obj.events.each do |id, ev|
    next unless ev
    ev.pages.each_with_index do |pg, pi|
      next unless pg.list
      pg.list.each_with_index do |cmd, ci|
        if [221,222,223,224].include?(cmd.code)
          # only report if event name suggests cat scene?
          # For now count all and print those with tint that has no matching fade/tint reset
          puts "#{fname} ev#{id} '#{ev.name[0,40]}' pg#{pi} [#{ci}] code=#{cmd.code} params=#{cmd.parameters.inspect} trigger=#{pg.trigger} cond=#{pg.condition.inspect[0,200]}"
        end
      end
    end
  end
end

puts "\n\n=== Detailed enemy example (first 5 maps with battle events) ==="
["Data/Map002.rvdata2","Data/Map003.rvdata2","Data/Map012.rvdata2","Data/Map020.rvdata2"].each do |fname|
  next unless File.exist?(fname)
  obj = Marshal.load(File.binread(fname))
  puts "\n--- #{fname} map_id=#{obj.instance_variable_get(:@map_id) rescue '?' if obj} ---"
  count=0
  obj.events.each do |id, ev|
    next unless ev
    has_battle = ev.pages.any?{|pg| pg.list.any?{|c| c.code==301}}
    next unless has_battle
    count+=1
    puts "Event #{id} '#{ev.name}' @#{ev.x},#{ev.y} pages=#{ev.pages.size}"
    ev.pages.each_with_index do |pg, pi|
      cond = pg.condition
      gfx = pg.graphic
      gfx_name = gfx ? gfx.character_name : ""
      gfx_tile = gfx ? gfx.tile_id : "?"
      walk_anime = pg.walk_anime rescue "?"
      step_anime = pg.step_anime rescue "?"
      trig = pg.trigger
      puts " Page#{pi} trig=#{trig} cond_self_switch_valid=#{cond.self_switch_valid rescue '?'} cond_sw_ch=#{cond.self_switch_ch.inspect rescue '?'} gfx=#{gfx_name.inspect} tile=#{gfx_tile} walk=#{walk_anime} step=#{step_anime} dir_fix=#{pg.direction_fix rescue '?'} through=#{pg.through rescue '?'}"
      puts "  codes: #{pg.list.map{|c| c.code}.join(',')}"
      pg.list.each_with_index do |cmd, ci|
        if [301,601,602,605,0,205,505,123,121,122,223,224,231,232,235,121,355,655,108,408].include?(cmd.code)
          puts "    [#{ci}] #{cmd.code} #{cmd.parameters.inspect[0,300]}"
        end
        # also dump comment contents for 108/408
        if cmd.code==108 || cmd.code==408
          puts "      COMMENT: #{cmd.parameters[0].inspect[0,200]}" if cmd.parameters[0].to_s.strip.length>0
        end
      end
    end
    break if count>=3
  end
end

puts "\n\n=== CommonEvents tint/fade detailed (first 20) ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
arr.each_with_index do |ce, idx|
  next unless ce && ce.list
  has = ce.list.any?{|c| [221,222,223,224,231,232,235].include?(c.code)}
  next unless has
  puts "\nCE idx#{idx} id=#{ce.id} name=#{ce.name.inspect} trigger=#{ce.trigger} switch=#{ce.switch_id}"
  ce.list.each_with_index do |cmd, ci|
    if [221,222,223,224,231,232,235,101,401,102,402,404,121,122,123,117,250,224].include?(cmd.code)
      puts "  [#{ci}] #{cmd.code} #{cmd.parameters.inspect[0,350]}"
    end
  end
end
