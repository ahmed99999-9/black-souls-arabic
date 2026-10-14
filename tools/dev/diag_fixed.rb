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

# Helper to get events hash from Map
def map_events(obj)
  obj.instance_variable_get(:@events) rescue (obj.events rescue {})
end

# 1. Pictures on disk
pics_disk = Dir["Graphics/Pictures/*"].map{|p| File.basename(p).downcase}
pics_base = pics_disk.map{|f| File.basename(f, ".*").downcase }
puts "=== Pictures on disk: #{pics_disk.size} ==="
puts pics_disk.sort.first(30).join(", ")
puts ""

# Collect ShowPicture refs
refs = Hash.new(0)
ref_locs = Hash.new{|h,k| h[k]=[]}
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin
    obj = Marshal.load(File.binread(path))
  rescue => e
    puts "LOAD FAIL #{path}: #{e.class} #{e.message[0,100]}"
    next
  end
  events = map_events(obj)
  next unless events && events.is_a?(Hash)
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil
    next unless pages
    pages.each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue nil
      next unless list
      list.each do |cmd|
        next unless cmd
        code = cmd.instance_variable_get(:@code) rescue nil
        next unless code==231
        params = cmd.instance_variable_get(:@parameters) rescue nil
        next unless params
        name = params[1].to_s
        next if name.nil? || name.empty?
        key = name.downcase
        refs[key]+=1
        ref_locs[key] << "#{File.basename(path)}:ev#{eid}:pg#{pi}"
      end
    end
  end
end
# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  puts "CommonEvents loaded: #{arr.compact.size} entries (array size #{arr.size})"
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue nil
    next unless list
    list.each do |cmd|
      code = cmd.instance_variable_get(:@code) rescue nil
      next unless code==231
      params = cmd.instance_variable_get(:@parameters) rescue nil
      next unless params
      name = params[1].to_s
      next if name.nil?||name.empty?
      key=name.downcase
      refs[key]+=1
      ref_locs[key] << "CommonEvents[#{idx}]:#{ce.instance_variable_get(:@id)}:#{ce.instance_variable_get(:@name).inspect}"
    end
  end
rescue => e
  puts "CE load fail #{e.class} #{e.message} #{e.backtrace[0,2]}"
end
puts "=== ShowPicture unique refs: #{refs.size} ==="
sorted = refs.sort_by{|k,v| -v}
sorted.each do |name,cnt|
  exists = pics_base.include?(name.downcase)
  status = exists ? "OK" : "MISSING"
  puts "#{status} #{name.inspect.ljust(30)} cnt=#{cnt.to_s.rjust(3)} locs=#{ref_locs[name].first(2).join('; ')}"
end
missing = sorted.select{|name,cnt| !pics_base.include?(name.downcase)}
puts "\nMissing distinct: #{missing.size}"
missing.first(20).each{|n,c| puts " MISSING #{n.inspect} cnt=#{c} loc=#{ref_locs[n].first(3).join(', ')}"}

puts "\n\n=== Tint / Fadeout unpaired analysis ==="
# Find pages with fadeout (221) without fadein (222) in same page
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = map_events(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    name = ev.instance_variable_get(:@name) rescue "?"
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages
    pages.each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue nil; next unless list
      codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
      has_out = codes.include?(221)
      has_in  = codes.include?(222)
      has_tint = codes.include?(223)
      if has_out && !has_in
        trig = pg.instance_variable_get(:@trigger) rescue "?"
        cond = pg.instance_variable_get(:@condition) rescue nil
        cond_s = cond ? "self_valid=#{cond.instance_variable_get(:@self_switch_valid) rescue '?'} ch=#{cond.instance_variable_get(:@self_switch_ch).inspect rescue '?'}" : "?"
        puts "#{File.basename(path)} ev#{eid} '#{name[0,30]}' pg#{pi} trig#{trig} #{cond_s} OUT without IN codes=#{codes.join(',')[0,150]}"
      end
      if has_tint
        list.each_with_index do |cmd, ci|
          code = cmd.instance_variable_get(:@code) rescue nil
          next unless code==223
          params = cmd.instance_variable_get(:@parameters) rescue nil
          next unless params
          tone = params[0]
          dur = params[1] rescue "?"
          wait = params[2] rescue "?"
          r = tone.instance_variable_get(:@red) rescue "?"
          g = tone.instance_variable_get(:@green) rescue "?"
          b = tone.instance_variable_get(:@blue) rescue "?"
          gr = tone.instance_variable_get(:@gray) rescue "?"
          puts "  TINT #{File.basename(path)} ev#{eid} pg#{pi} [#{ci}] tone=#{r},#{g},#{b},#{gr} dur=#{dur} wait=#{wait}"
        end
      end
    end
  end
end

# CommonEvents fade analysis
puts "\n=== CommonEvents fade analysis ==="
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue nil; next unless list
    codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
    next unless codes.include?(221) || codes.include?(223)
    name = ce.instance_variable_get(:@name) rescue "?"
    trig = ce.instance_variable_get(:@trigger) rescue "?"
    has_in = codes.include?(222)
    puts "CE#{idx} id=#{ce.instance_variable_get(:@id) rescue '?'} name=#{name.inspect[0,50]} trig=#{trig} has_out=#{codes.include?(221)} has_in=#{has_in} tint=#{codes.include?(223)} total=#{codes.size} counts 221=#{codes.count(221)} 222=#{codes.count(222)}"
    if codes.include?(221) && !has_in
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code) rescue nil
        if [221,222,223,224,231,235,101,401,117].include?(code)
          params = cmd.instance_variable_get(:@parameters) rescue nil
          puts " [#{ci}] code=#{code} #{params.inspect[0,300]}"
        end
      end
    end
    if codes.include?(223)
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code) rescue nil
        next unless code==223
        params=cmd.instance_variable_get(:@parameters) rescue nil
        tone=params[0]; dur=params[1]; wait=params[2] rescue nil
        r=tone.instance_variable_get(:@red) rescue "?"; g=tone.instance_variable_get(:@green) rescue "?"; b=tone.instance_variable_get(:@blue) rescue "?"; gr=tone.instance_variable_get(:@gray) rescue "?"
        puts "  TINT CE#{idx} [#{ci}] tone=#{r},#{g},#{b},#{gr} dur=#{dur} wait=#{wait}"
      end
    end
  end
rescue => e
  puts "CE fade err #{e}"
end

# Enemy body stats
puts "\n\n=== Enemy body events summary ==="
total_enemy=0
death_stats=Hash.new(0)
erase_total=0
selfd=0; selfa=0; selfb=0; selfc=0
has_erase_detail=[]
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events=map_events(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    pages=ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    pg0=pages[0]
    list0=pg0.instance_variable_get(:@list) rescue nil; next unless list0
    has301 = list0.any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    next unless has301
    total_enemy+=1
    # count death pages (1..)
    if pages.size>=2
      pages[1..-1].each_with_index do |pg, idx|
        pi=idx+1
        list=pg.instance_variable_get(:@list) rescue nil; next unless list
        has214 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==214}
        has123 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==123}
        trig=pg.instance_variable_get(:@trigger) rescue nil
        cond=pg.instance_variable_get(:@condition) rescue nil
        erase_total+=1 if has214
        list.each do |c|
          next unless (c.instance_variable_get(:@code) rescue nil)==123
          params=c.instance_variable_get(:@parameters) rescue nil; next unless params
          ch=params[0]
          selfd+=1 if ch=="D"
          selfa+=1 if ch=="A"
          selfb+=1 if ch=="B"
          selfc+=1 if ch=="C"
        end
        key="trig#{trig}_214#{has214}_123#{has123}"
        death_stats[key]+=1
        if has214
          has_erase_detail << [File.basename(path), eid, pi, list.map{|c| c.instance_variable_get(:@code) rescue nil}.join(",")[0,150]]
        end
      end
    else
      death_stats["single_page"]+=1
    end
  end
end
puts "total enemy events (symbol encounters with 301 on pg0): #{total_enemy}"
puts "death page stats: #{death_stats.inspect}"
puts "erase_total pages=#{erase_total} self D=#{selfd} A=#{selfa} B=#{selfb} C=#{selfc}"
puts "Examples with EraseEvent:"
has_erase_detail.first(10).each{|d| puts " #{d.inspect}"}

# Detailed example for first battle map
puts "\n\n=== Detailed first battle map enemies ==="
found_maps=[]
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events=map_events(obj); next unless events
  cnt=0
  events.each do |eid, ev|
    next unless ev
    pages=ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    has301 = (pages[0].instance_variable_get(:@list) rescue []).any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    cnt+=1 if has301
  end
  found_maps << [path,cnt] if cnt>0
end
found_maps.sort_by{|p,c| -c}.first(3).each do |path,cnt|
  puts "\n--- #{File.basename(path)} enemies=#{cnt} ---"
  obj=Marshal.load(File.binread(path))
  events=map_events(obj)
  shown=0
  events.each do |eid, ev|
    next unless ev
    pages=ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    has301 = (pages[0].instance_variable_get(:@list) rescue []).any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    next unless has301
    shown+=1
    name=ev.instance_variable_get(:@name) rescue "?"
    x=ev.instance_variable_get(:@x) rescue "?"; y=ev.instance_variable_get(:@y) rescue "?"
    puts "Event #{eid} '#{name}' @#{x},#{y} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      trig=pg.instance_variable_get(:@trigger) rescue "?"
      cond=pg.instance_variable_get(:@condition) rescue nil
      cond_s = cond ? "self_valid=#{cond.instance_variable_get(:@self_switch_valid) rescue '?'} ch=#{cond.instance_variable_get(:@self_switch_ch).inspect rescue '?'} sw1=#{cond.instance_variable_get(:@switch1_valid) rescue '?'}:#{cond.instance_variable_get(:@switch1_id) rescue '?'}" : "nil"
      gfx=pg.instance_variable_get(:@graphic) rescue nil
      gfx_s = gfx ? "tile=#{gfx.instance_variable_get(:@tile_id) rescue '?'} char=#{gfx.instance_variable_get(:@character_name).inspect rescue '?'} idx=#{gfx.instance_variable_get(:@character_index) rescue '?'}" : "nil"
      list=pg.instance_variable_get(:@list) rescue nil
      codes = list ? list.map{|c| c.instance_variable_get(:@code) rescue "?"}.join(",") : ""
      puts " pg#{pi} trig=#{trig} #{cond_s} gfx=[#{gfx_s}] codes=#{codes[0,300]}"
      next unless list
      list.each_with_index do |cmd, ci|
        code=cmd.instance_variable_get(:@code) rescue nil
        params=cmd.instance_variable_get(:@parameters) rescue nil
        indent=cmd.instance_variable_get(:@indent) rescue "?"
        next unless [301,601,602,603,605,205,505,123,122,121,214,132,355,655,108,408,101,401].include?(code)
        puts "  [#{ci}] indent#{indent} code#{code} #{params.inspect[0,500]}"
        if code==205 && params
          mr=params[1]
          if mr
            ml=mr.instance_variable_get(:@list) rescue []
            ml.each do |mc|
              puts "    MR code=#{mc.instance_variable_get(:@code) rescue '?'} params=#{mc.instance_variable_get(:@parameters).inspect[0,120]}"
            end
          end
        end
        if code==108||code==408
          puts "    COMMENT #{params[0].inspect[0,200]}" if params[0].to_s.strip.length>0
        end
      end
    end
    break if shown>=2
  end
end
