#!/usr/bin/env ruby
# encoding: utf-8
class Table; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; end
class Color; def self._load(s); allocate; end; def _dump(l); ""; end; def initialize(*a); end; end
class Tone; def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end; def _dump(l); @_raw||""; end; def initialize(*a); end; end
module RPG
  class Map; class Encounter; end; end
  class Event; class Page; class Condition; end; class Graphic; end; end
  class MoveRoute; end
  class MoveCommand; end
  class EventCommand; end
  class CommonEvent; end
  class System; end
  class Troop; class Page; end; class Member; end; end
  class Actor; end; class Class; end; class Skill; end; class Item; end; class Weapon; end; class Armor; end; class Enemy; end; class State; end; class Animation; end; class Tileset; end; class AudioFile; end; class BGM; end; class BGS; end; class SE; end; class ME; end; class MapInfo; end
end
require 'zlib'

def load_map(path)
  Marshal.load(File.binread(path))
rescue => e
  puts "fail #{path} #{e}"
  nil
end

# 1. CE names dump with proper UTF-8
puts "=== CommonEvents names ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
arr.each_with_index do |ce, idx|
  next unless ce
  id = ce.instance_variable_get(:@id) rescue idx
  name = ce.instance_variable_get(:@name) rescue ""
  name = name.encode("UTF-8", invalid: :replace, undef: :replace) rescue name.inspect
  # show only those with black or with fade
  list = ce.instance_variable_get(:@list) rescue []
  codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
  has_black = codes.include?(231) && list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==231 && (c.instance_variable_get(:@parameters)[1].to_s rescue "")=="black"}
  has_fade = codes.include?(221)
  if has_black || has_fade || idx==201 || idx.between?(74,85)
    puts "CE idx#{idx} id=#{id} name=#{name.inspect} trig=#{ce.instance_variable_get(:@trigger) rescue '?'} codes221=#{codes.count(221)} 222=#{codes.count(222)} 231=#{codes.count(231)} len=#{list.size}"
  end
end

# detail CE201
puts "\n=== CE201 detailed ==="
ce201 = arr[201]
if ce201
  id = ce201.instance_variable_get(:@id)
  name = ce201.instance_variable_get(:@name)
  puts "CE201 id=#{id} name=#{name.encode('UTF-8', invalid: :replace) rescue name.inspect}"
  list = ce201.instance_variable_get(:@list)
  list.each_with_index do |cmd, ci|
    code = cmd.instance_variable_get(:@code) rescue nil
    params = cmd.instance_variable_get(:@parameters) rescue nil
    indent = cmd.instance_variable_get(:@indent) rescue 0
    # decode 401 text if present
    if code==401
      txt = params[0].to_s.encode("UTF-8", invalid: :replace)[0,80].inspect rescue params[0].inspect[0,80]
      puts "[#{ci}] indent#{indent} 401 #{txt}"
    elsif [221,222,223,224,231,232,235,101,108,408,121,122].include?(code)
      puts "[#{ci}] indent#{indent} code#{code} #{params.inspect[0,600]}"
    elsif ci<15 || ci>115
      puts "[#{ci}] indent#{indent} code#{code} #{params.inspect[0,300]}"
    end
  end
end

# detail CE74
puts "\n=== CE74 first 35 vs last 20 ==="
ce74 = arr[74]
if ce74
  list = ce74.instance_variable_get(:@list)
  puts "CE74 len #{list.size}"
  (0..35).each do |ci|
    cmd = list[ci]
    code = cmd.instance_variable_get(:@code) rescue nil
    params = cmd.instance_variable_get(:@parameters) rescue nil
    puts "[#{ci}] code#{code} #{params.inspect[0,500]}"
  end
  puts "..."
  ((list.size-25)..(list.size-1)).each do |ci|
    next if ci<0
    cmd = list[ci]
    code = cmd.instance_variable_get(:@code) rescue nil
    params = cmd.instance_variable_get(:@parameters) rescue nil
    puts "[#{ci}] code#{code} #{params.inspect[0,500]}"
  end
end

# 2. Check picture dimensions
puts "\n=== Picture dimensions via PNG IHDR ==="
Dir["Graphics/Pictures/*.png"].sort.first(10).each do |path|
  data = File.binread(path)[0,100] rescue ""
  if data[0,8] == "\x89PNG\r\n\x1A\n".b
    w = data[16,4].unpack('N')[0] rescue 0
    h = data[20,4].unpack('N')[0] rescue 0
    puts "#{File.basename(path)} #{w}x#{h} size #{File.size(path)}"
  else
    puts "#{File.basename(path)} not PNG header size #{File.size(path)}"
  end
end
# check black
["Graphics/Pictures/black.png","Graphics/Pictures/black.jpg","Graphics/Pictures/001.png","Graphics/Pictures/59.png"].each do |p|
  if File.exist?(p)
    puts "#{p} exists size #{File.size(p)}"
    if p.end_with?(".png")
      data = File.binread(p)[0,100]
      if data[0,8] == "\x89PNG\r\n\x1A\n".b
        w = data[16,4].unpack('N')[0] rescue 0
        h = data[20,4].unpack('N')[0] rescue 0
        puts "  => #{w}x#{h}"
      end
    else
      # jpg check via reading? skip
      puts "  => JPG file"
    end
  else
    puts "#{p} MISSING"
  end
end

# 3. Check System for screen size and battlebacks
puts "\n=== System.rvdata2 check ==="
begin
  sys = Marshal.load(File.binread("Data/System.rvdata2"))
  # sys has many ivars
  puts "System ivars: #{sys.instance_variables.map(&:to_s).join(', ')[0,500]}"
  # try to get window size? In VX Ace, Graphics.width is 544, height 416 default, but System may have?
  # Check battleback names
  puts "battleback1 #{sys.instance_variable_get(:@battleback1_name).inspect rescue '?'}"
  puts "battleback2 #{sys.instance_variable_get(:@battleback2_name).inspect rescue '?'}"
  # check switches/variables size
  puts "switches #{(sys.instance_variable_get(:@switches).size rescue '?')} variables #{(sys.instance_variable_get(:@variables).size rescue '?')}"
rescue => e
  puts "System load fail #{e}"
end

# 4. Check Scripts for Cache and Arabic
puts "\n=== Scripts titles search ==="
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
scripts.each_with_index do |e,i|
  t = e[1].to_s.encode("UTF-8", invalid: :replace, undef: :replace) rescue e[1].inspect
  # look for arabic or reshaper or cache
  low = t.downcase rescue ""
  if low.include?("cache") || low.include?("arabic") || low.include?("reshap") || low.include?("message") && i>140 || t.include?("Cache")
    puts "#{i}: #{t.inspect} id=#{e[0]} len=#{Zlib::Inflate.inflate(e[2]).bytesize rescue e[2].bytesize}"
  end
end
# also find index for Cache specifically
cache_idx = scripts.index{|e| e[1].to_s.include?("Cache") }
puts "Cache idx=#{cache_idx}"
if cache_idx
  e = scripts[cache_idx]
  content = Zlib::Inflate.inflate(e[2]) rescue e[2]
  content = content.encode("UTF-8", invalid: :replace, undef: :replace) rescue content
  puts content[0,3000]
end

# 5. Enemy fix analysis - show one enemy before fix details
puts "\n=== One enemy before fix raw ==="
map = Marshal.load(File.binread("Data/Map049.rvdata2"))
events = map.instance_variable_get(:@events)
ev = events[6]
pages = ev.instance_variable_get(:@pages)
pages.each_with_index do |pg, pi|
  cond = pg.instance_variable_get(:@condition)
  gfx = pg.instance_variable_get(:@graphic)
  puts "pg#{pi} trig=#{pg.instance_variable_get(:@trigger)} cond_self=#{cond.instance_variable_get(:@self_switch_valid)}:#{cond.instance_variable_get(:@self_switch_ch).inspect} gfx tile=#{gfx.instance_variable_get(:@tile_id)} char=#{gfx.instance_variable_get(:@character_name).inspect} through=#{pg.instance_variable_get(:@through)} walk=#{pg.instance_variable_get(:@walk_anime)}"
  list = pg.instance_variable_get(:@list)
  puts " codes: #{list.map{|c| c.instance_variable_get(:@code)}.join(',')}"
end
