#!/usr/bin/env ruby
# encoding: utf-8
# Proper stubs for RPG VX Ace Marshal loading - based on black_diag success pattern
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

# helper
def ev_hash(obj)
  obj.instance_variable_get(:@events) rescue {}
end

puts "=== DIAG: Picture refs vs disk ==="
pics_disk = Dir["Graphics/Pictures/*"].map{|p| File.basename(p)}
pics_disk_down = pics_disk.map(&:downcase)
pics_base = pics_disk.map{|p| File.basename(p, ".*").downcase}
puts "disk count #{pics_disk.size}: #{pics_disk.sort.first(30).join(', ')}"

refs = Hash.new(0)
ref_details = Hash.new{|h,k| h[k]=[]}
# scan Maps
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin
    obj = Marshal.load(File.binread(path))
  rescue => e
    puts "MAP LOAD FAIL #{path}: #{e}"
    next
  end
  events = ev_hash(obj) || {}
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil
    next unless pages
    pages.each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue nil
      next unless list
      list.each do |cmd|
        code = cmd.instance_variable_get(:@code) rescue nil
        params = cmd.instance_variable_get(:@parameters) rescue nil
        if code == 231
          pic = params[1].to_s rescue ""
          next if pic.empty?
          key = pic.downcase
          refs[key]+=1
          ref_details[key] << "#{File.basename(path)}:ev#{eid}:pg#{pi}"
        end
      end
    end
  end
end
# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  puts "CommonEvents total #{arr.size} non-nil #{arr.compact.size}"
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue nil
    next unless list
    list.each do |cmd|
      code = cmd.instance_variable_get(:@code) rescue nil
      next unless code==231
      params = cmd.instance_variable_get(:@parameters) rescue nil
      next unless params
      pic = params[1].to_s rescue ""
      next if pic.empty?
      key = pic.downcase
      refs[key]+=1
      ce_name = ce.instance_variable_get(:@name) rescue "?"
      ce_id = ce.instance_variable_get(:@id) rescue "?"
      ref_details[key] << "CE#{idx}:id#{ce_id}:#{ce_name.to_s[0,30].inspect}"
    end
  end
rescue => e
  puts "CE load fail #{e} #{e.backtrace[0,2]}"
end

puts "\nUnique picture refs #{refs.size}"
missing = []
refs.sort_by{|k,v| -v}.each do |pic, cnt|
  exists = pics_base.include?(pic)
  status = exists ? "OK" : "MISSING"
  if !exists
    missing << pic
    puts "  #{status} #{pic.inspect} cnt=#{cnt} ex=#{ref_details[pic].first(2).join('; ')}"
  end
end
if missing.empty?
  puts "No missing pictures! All refs found on disk."
  # show top 20 refs for verification
  refs.sort_by{|k,v| -v}.first(20).each do |pic,cnt|
    puts "  OK #{pic.inspect} cnt=#{cnt}"
  end
else
  puts "MISSING total #{missing.size}"
end

# Also check black.png vs black.jpg
puts "\n=== black files check ==="
puts "black.png exists #{File.exist?('Graphics/Pictures/black.png')} size #{File.size('Graphics/Pictures/black.png') rescue '?'}"
puts "black.jpg exists #{File.exist?('Graphics/Pictures/black.jpg')} size #{File.size('Graphics/Pictures/black.jpg') rescue '?'}"
# Try to read PNG header to get dimensions (simple)
if File.exist?('Graphics/Pictures/black.png')
  data = File.binread('Graphics/Pictures/black.png')[0, 100]
  # PNG IHDR is at offset 16: 4 bytes width, 4 bytes height big-endian
  if data[0,8] == "\x89PNG\r\n\x1A\n".b
    w = data[16,4].unpack('N')[0] rescue '?'
    h = data[20,4].unpack('N')[0] rescue '?'
    puts "black.png dimensions #{w}x#{h} (PNG header)"
  end
end

puts "\n=== CG pictures existence spot check (001, 59, 60, 42, 49, 50, 51 etc) ==="
%w[001 59 60 42 49 50 51 002 003].each do |n|
  exists_png = File.exist?("Graphics/Pictures/#{n}.png")
  exists_jpg = File.exist?("Graphics/Pictures/#{n}.jpg")
  puts "#{n}: png=#{exists_png} jpg=#{exists_jpg} files=#{Dir["Graphics/Pictures/#{n}.*"].join(', ')}"
end

puts "\n\n=== Fade/Tint/Flash unpaired per page ==="
unpaired = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = ev_hash(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages
    pages.each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue nil; next unless list
      codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
      has_out = codes.include?(221)
      has_in = codes.include?(222)
      if has_out && !has_in
        trig = pg.instance_variable_get(:@trigger) rescue "?"
        cond = pg.instance_variable_get(:@condition) rescue nil
        name = ev.instance_variable_get(:@name) rescue "?"
        puts "#{File.basename(path)} ev#{eid} '#{name.to_s[0,30]}' pg#{pi} trig#{trig} OUT without IN codes=#{codes.join(',')[0,120]}"
        unpaired << [path,eid,pi]
      end
    end
  end
end
puts "Unpaired fadeout pages count: #{unpaired.size}"

# CommonEvents fade
puts "\n=== CommonEvents fade analysis ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
arr.each_with_index do |ce, idx|
  next unless ce
  list = ce.instance_variable_get(:@list) rescue nil; next unless list
  codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
  next unless codes.include?(221)
  has_in = codes.include?(222)
  name = ce.instance_variable_get(:@name) rescue "?"
  id = ce.instance_variable_get(:@id) rescue "?"
  puts "CE#{idx} id=#{id} name=#{name.to_s[0,40].inspect} has_out=#{codes.include?(221)} has_in=#{has_in} 221cnt=#{codes.count(221)} 222cnt=#{codes.count(222)} len=#{list.size} trig=#{ce.instance_variable_get(:@trigger) rescue '?'}"
  if !has_in
    list.each_with_index do |cmd, ci|
      code = cmd.instance_variable_get(:@code) rescue nil
      if [221,222,223,224,231,235].include?(code)
        params = cmd.instance_variable_get(:@parameters) rescue nil
        puts " [#{ci}] code=#{code} #{params.inspect[0,300]}"
      end
    end
  end
end

puts "\n\n=== Enemy body events ==="
total_enemy=0
death_stats=Hash.new(0)
erase_total=0
self_switch_counts=Hash.new(0)
detail_examples=[]
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = ev_hash(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    pg0 = pages[0]
    list0 = pg0.instance_variable_get(:@list) rescue nil; next unless list0
    has301 = list0.any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    next unless has301
    total_enemy+=1
    if pages.size < 2
      death_stats["single_page_no_death_page"]+=1
    else
      pages[1..-1].each_with_index do |pg, idx|
        pi = idx+1
        list = pg.instance_variable_get(:@list) rescue nil; next unless list
        has214 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==214}
        has123 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==123}
        trig = pg.instance_variable_get(:@trigger) rescue nil
        cond = pg.instance_variable_get(:@condition) rescue nil
        self_valid = cond.instance_variable_get(:@self_switch_valid) rescue nil
        self_ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
        gfx = pg.instance_variable_get(:@graphic) rescue nil
        tile_id = gfx.instance_variable_get(:@tile_id) rescue nil
        char_name = gfx.instance_variable_get(:@character_name) rescue nil
        erase_total+=1 if has214
        list.each do |c|
          if (c.instance_variable_get(:@code) rescue nil)==123
            params = c.instance_variable_get(:@parameters) rescue nil
            ch = params[0] rescue "?"
            self_switch_counts[ch]+=1
          end
        end
        key="trig#{trig}_self#{self_ch}_214#{has214}_123#{has123}_tile#{tile_id}_char#{char_name.to_s[0,10].inspect}"
        # simplify key for stats
        skey="trig#{trig}_214#{has214}_123#{has123}_self#{self_ch}"
        death_stats[skey]+=1
        if detail_examples.size<5 && has214
          detail_examples << [File.basename(path), eid, pi, trig, self_ch, list.map{|c| c.instance_variable_get(:@code) rescue nil}.join(',')[0,200]]
        end
        if detail_examples.size<10 && !has214 && !has123
          detail_examples << ["NO_ERASE_NO_SWITCH", File.basename(path), eid, pi, list.map{|c| c.instance_variable_get(:@code) rescue nil}.join(',')[0,200]]
        end
      end
    end
  end
end
puts "total enemy events (BattleProcessing on pg0): #{total_enemy}"
puts "death page stats (grouped):"
death_stats.each do |k,v|
  puts "  #{k} => #{v}"
end
puts "erase_total #{erase_total} self_switch #{self_switch_counts.inspect}"
puts "examples:"
detail_examples.each{|d| puts " #{d.inspect}"}

# More detailed enemy example for largest map
puts "\n\n=== Detailed largest enemy map ==="
maps_with_enemies = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = ev_hash(obj); next unless events
  cnt = 0
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    has301 = (pages[0].instance_variable_get(:@list) rescue []).any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    cnt+=1 if has301
  end
  maps_with_enemies << [path,cnt] if cnt>0
end
maps_with_enemies.sort_by{|p,c| -c}.first(3).each do |path,cnt|
  puts "\n--- #{File.basename(path)} enemies=#{cnt} display=#{Marshal.load(File.binread(path)).instance_variable_get(:@display_name).inspect rescue '?'} ---"
  obj = Marshal.load(File.binread(path))
  events = ev_hash(obj)
  shown=0
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages && !pages.empty?
    has301 = (pages[0].instance_variable_get(:@list) rescue []).any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    next unless has301
    shown+=1
    name = ev.instance_variable_get(:@name) rescue "?"
    x = ev.instance_variable_get(:@x) rescue "?"
    y = ev.instance_variable_get(:@y) rescue "?"
    puts "Event #{eid} '#{name}' @#{x},#{y} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      trig = pg.instance_variable_get(:@trigger) rescue "?"
      cond = pg.instance_variable_get(:@condition) rescue nil
      cond_s = cond ? "self_valid=#{cond.instance_variable_get(:@self_switch_valid) rescue '?'} ch=#{cond.instance_variable_get(:@self_switch_ch).inspect rescue '?'} sw1=#{cond.instance_variable_get(:@switch1_valid) rescue '?'}:#{cond.instance_variable_get(:@switch1_id) rescue '?'}" : "nil"
      gfx = pg.instance_variable_get(:@graphic) rescue nil
      gfx_s = gfx ? "tile=#{gfx.instance_variable_get(:@tile_id) rescue '?'} char=#{gfx.instance_variable_get(:@character_name).inspect rescue '?'} idx=#{gfx.instance_variable_get(:@character_index) rescue '?'}" : "nil"
      walk = pg.instance_variable_get(:@walk_anime) rescue "?"
      step = pg.instance_variable_get(:@step_anime) rescue "?"
      dirfix = pg.instance_variable_get(:@direction_fix) rescue "?"
      through = pg.instance_variable_get(:@through) rescue "?"
      list = pg.instance_variable_get(:@list) rescue nil
      codes = list ? list.map{|c| c.instance_variable_get(:@code) rescue "?"}.join(",") : ""
      puts " pg#{pi} trig=#{trig} #{cond_s} gfx=[#{gfx_s}] walk=#{walk} step=#{step} dirfix=#{dirfix} through=#{through} codes=#{codes[0,300]}"
      next unless list
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code) rescue nil
        params = cmd.instance_variable_get(:@parameters) rescue nil
        indent = cmd.instance_variable_get(:@indent) rescue "?"
        next unless [301,601,602,605,205,505,123,122,121,214,132,355,655,108,408,101,401,121,250,335].include?(code)
        puts "  [#{ci}] indent#{indent} code#{code} #{params.inspect[0,500]}"
        if code==205 && params
          mr = params[1]
          if mr
            ml = mr.instance_variable_get(:@list) rescue []
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
