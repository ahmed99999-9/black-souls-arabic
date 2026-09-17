#!/usr/bin/env ruby
# encoding: utf-8
class Table; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; end
class Color; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); ""; end; def initialize(*a); end; end
class Tone; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); ""; end; def initialize(*a); end; end
module RPG
  class Map; class Encounter; end; end
  class Event; class Page; class Condition; end; class Graphic; end; end
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
require 'zlib'

def ev_list(obj)
  # Map object .instance_variable_get(:@events) is hash of id=>RPG::Event
  events = obj.instance_variable_get(:@events) if obj
  events
end

def page_condition_str(pg)
  cond = pg.instance_variable_get(:@condition)
  return "nil" unless cond
  "sw1:#{cond.instance_variable_get(:@switch1_valid)}:#{cond.instance_variable_get(:@switch1_id)} sw2:#{cond.instance_variable_get(:@switch2_valid)}:#{cond.instance_variable_get(:@switch2_id)} var:#{cond.instance_variable_get(:@variable_valid)} self:#{cond.instance_variable_get(:@self_switch_valid)}:#{cond.instance_variable_get(:@self_switch_ch).inspect} item:#{cond.instance_variable_get(:@item_valid)} actor:#{cond.instance_variable_get(:@actor_valid)}"
end

def graphic_str(pg)
  g = pg.instance_variable_get(:@graphic)
  return "nil" unless g
  tn = g.instance_variable_get(:@tile_id)
  cn = g.instance_variable_get(:@character_name)
  ci = g.instance_variable_get(:@character_index)
  "tile=#{tn} char=#{cn.inspect} idx=#{ci}"
end

# ---- 1. Find all maps with battle events (code 301) ----
puts "=== Maps with Battle Processing (symbol encounters) ==="
battle_maps=[]
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  begin
    obj = Marshal.load(File.binread(fname))
    events = ev_list(obj)
    next unless events
    battles = []
    events.each do |eid, ev|
      next unless ev
      pages = ev.instance_variable_get(:@pages) || []
      has = pages.any? do |pg|
        list = pg.instance_variable_get(:@list) || []
        list.any?{|c| c.instance_variable_get(:@code)==301}
      end
      if has
        battles << eid
      end
    end
    if battles.size>0
      display = obj.instance_variable_get(:@display_name)
      battle_maps << fname
      puts "#{fname} display=#{display.inspect} battles=#{battles.size} ids=#{battles.first(10).inspect}"
    end
  rescue => e
    puts "ERR #{fname}: #{e.class} #{e.message}"
  end
end
puts "total battle maps: #{battle_maps.size}"

# ---- 2. Inspect 3 specific maps deeply ----
puts "\n=== Deep inspect up to 3 battle maps ==="
battle_maps.first(3).each do |fname|
  obj = Marshal.load(File.binread(fname))
  events = ev_list(obj)
  puts "\n--- #{fname} #{obj.instance_variable_get(:@display_name).inspect} ---"
  shown=0
  events.each do |eid, ev|
    next unless ev
    name = ev.instance_variable_get(:@name)
    x = ev.instance_variable_get(:@x)
    y = ev.instance_variable_get(:@y)
    pages = ev.instance_variable_get(:@pages) || []
    has301 = pages.any?{|pg| (pg.instance_variable_get(:@list)||[]).any?{|c| c.instance_variable_get(:@code)==301}}
    next unless has301
    shown+=1
    puts "\nEvent #{eid} '#{name}' @#{x},#{y} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      trig = pg.instance_variable_get(:@trigger)
      priority = pg.instance_variable_get(:@priority_type)
      through = pg.instance_variable_get(:@through)
      dir_fix = pg.instance_variable_get(:@direction_fix)
      walk = pg.instance_variable_get(:@walk_anime)
      step = pg.instance_variable_get(:@step_anime)
      conds = page_condition_str(pg)
      gfx = graphic_str(pg)
      list = pg.instance_variable_get(:@list) || []
      codes = list.map{|c| c.instance_variable_get(:@code)}
      puts " Page#{pi} trig=#{trig} pri=#{priority} thr=#{through} dirfix=#{dir_fix} walk=#{walk} step=#{step} cond=[#{conds}] gfx=[#{gfx}] codes=#{codes.join(',')}"
      # dump list details
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code)
        params = cmd.instance_variable_get(:@parameters)
        indent = cmd.instance_variable_get(:@indent)
        if [108,408,101,401,102,402,404,103,405,121,122,123,250,251,236,223,224,221,222,225,231,232,235,205,505,301,601,602,603,605,355,655].include?(code)
          puts "  [#{ci}] indent=#{indent} code=#{code} params=#{params.inspect[0,500]}"
          if code==108||code==408
            puts "       comment: #{params[0].inspect[0,300]}" if params[0].to_s.strip.length>0
          end
          if code==205
            mr = params[1]
            if mr
              ml = mr.instance_variable_get(:@list)||[]
              puts "       move_route repeat=#{mr.instance_variable_get(:@repeat)} skippable=#{mr.instance_variable_get(:@skippable)} wait=#{mr.instance_variable_get(:@wait)}"
              ml.each{|mc| puts "         MC code=#{mc.instance_variable_get(:@code)} params=#{mc.instance_variable_get(:@parameters).inspect}"}
            end
          end
        end
      end
    end
    break if shown>=2
  end
end

# ---- 3. Pictures refs ----
puts "\n\n=== Picture references analysis ==="
pics_on_disk = Dir["Graphics/Pictures/*"].map{|p| File.basename(p,".*").downcase }
pics_full = Dir["Graphics/Pictures/*"].map{|p| File.basename(p).downcase}
puts "Pictures on disk: #{pics_on_disk.size} examples: #{pics_on_disk.first(20).join(', ')}"

refs = Hash.new(0)
ref_details = Hash.new{|h,k| h[k]=[]}
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  begin
    obj = Marshal.load(File.binread(fname))
    events = ev_list(obj)
    next unless events
    events.each do |eid, ev|
      next unless ev
      (ev.instance_variable_get(:@pages)||[]).each do |pg|
        (pg.instance_variable_get(:@list)||[]).each do |cmd|
          next unless cmd
          code=cmd.instance_variable_get(:@code)
          if code==231
            params=cmd.instance_variable_get(:@parameters)
            pic = params[1].to_s rescue ""
            next if pic.empty?
            refs[pic.downcase]+=1
            ref_details[pic.downcase] << "#{fname}:ev#{eid}"
          elsif code==232
            params=cmd.instance_variable_get(:@parameters)
            # Move Picture may have name?
          end
        end
      end
    end
  rescue => e
  end
end
# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list)||[]
    list.each do |cmd|
      code=cmd.instance_variable_get(:@code)
      if code==231
        pic = cmd.instance_variable_get(:@parameters)[1].to_s rescue ""
        next if pic.empty?
        refs[pic.downcase]+=1
        ref_details[pic.downcase] << "CE#{idx}:#{ce.instance_variable_get(:@name).inspect}"
      end
    end
  end
rescue => e
  puts "CE error #{e}"
end

puts "Unique pic refs: #{refs.size}"
refs.sort_by{|k,v| -v}.first(100).each do |pic, cnt|
  exists = pics_on_disk.include?(pic.downcase)
  status = exists ? "OK" : "MISSING"
  puts " #{status} #{pic.inspect} cnt=#{cnt} examples: #{ref_details[pic].first(2).join(' ; ')}"
end
missing = refs.keys.select{|pic| !pics_on_disk.include?(pic.downcase) }
puts "\nMissing pics: #{missing.size}"
missing.each{|m| puts "  MISSING #{m.inspect} cnt=#{refs[m]} refs=#{ref_details[m].first(3).join(', ')}"}

# Also check Erase Picture 235 coverage
puts "\n=== Erase Picture check ==="
erase_counts = Hash.new(0)
show_counts = Hash.new(0)
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  obj = Marshal.load(File.binread(fname))
  next unless obj
  events = ev_list(obj)
  next unless events
  events.each do |eid, ev|
    next unless ev
    (ev.instance_variable_get(:@pages)||[]).each do |pg|
      (pg.instance_variable_get(:@list)||[]).each do |cmd|
        code=cmd.instance_variable_get(:@code)
        if code==231
          show_counts[cmd.instance_variable_get(:@parameters)[0]]+=1
        elsif code==235
          erase_counts[cmd.instance_variable_get(:@parameters)[0]]+=1
        end
      end
    end
  end
end
puts "Show counts by pic number: #{show_counts.keys.sort.first(20).inspect} total #{show_counts.size}"
puts "Erase counts by pic number: #{erase_counts.keys.sort.first(20).inspect}"
puts "Show but never erase? #{(show_counts.keys - erase_counts.keys).sort.inspect}"

# ---- 4. Fade/Tint/Flash analysis ----
puts "\n\n=== Tint/Fade screening across maps ==="
Dir["Data/Map*.rvdata2"].sort.each do |fname|
  obj = Marshal.load(File.binread(fname))
  next unless obj
  events = ev_list(obj)
  next unless events
  events.each do |eid, ev|
    next unless ev
    name=ev.instance_variable_get(:@name)
    (ev.instance_variable_get(:@pages)||[]).each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list)||[]
      list.each_with_index do |cmd, ci|
        code=cmd.instance_variable_get(:@code)
        if [221,222,223,224,223].include?(code)
          params=cmd.instance_variable_get(:@parameters)
          indent=cmd.instance_variable_get(:@indent)
          trig=pg.instance_variable_get(:@trigger)
          conds=page_condition_str(pg)
          puts "#{fname} ev#{eid} '#{name}' pg#{pi} trig#{trig} cond[#{conds}] [#{ci}] code=#{code} indent=#{indent} params=#{params.inspect[0,600]}"
        end
      end
    end
  end
end

# Also CommonEvents tints/fades
puts "\n=== CommonEvents Tint/Fade ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
arr.each_with_index do |ce, idx|
  next unless ce
  list=ce.instance_variable_get(:@list)||[]
  has=list.any?{|c| [221,222,223,224].include?(c.instance_variable_get(:@code))}
  next unless has
  name=ce.instance_variable_get(:@name)
  puts "\nCE #{idx} id=#{ce.instance_variable_get(:@id)} name=#{name.inspect} trigger=#{ce.instance_variable_get(:@trigger)} switch=#{ce.instance_variable_get(:@switch_id)}"
  list.each_with_index do |cmd, ci|
    code=cmd.instance_variable_get(:@code)
    if [221,222,223,224,225,231,232,235,250,224,121,122,123].include?(code)
      puts " [#{ci}] code=#{code} params=#{cmd.instance_variable_get(:@parameters).inspect[0,500]}"
    end
  end
end
