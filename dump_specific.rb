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
  class Actor; end; class Class; end; class Skill; end; class Item; end; class Weapon; end; class Armor; end; class Enemy; end; class State; end; class Animation; end; class Tileset; end; class AudioFile; end; class BGM; end; class BGS; end; class SE; end; class ME; end; class MapInfo; end
end
require 'zlib'
data = File.binread("Data/Scripts.rvdata2")
scripts = Marshal.load(data)
# find scripts by title containing specific strings - handle encoding
scripts.each_with_index do |e,i|
  t = e[1] rescue ""
  # force encoding
  t = t.force_encoding("UTF-8") rescue t
  if t.include?("Body") || t.include?("Battle") && i>150 || t.include?("Arabic") || t.include?("Reshaper") || t.include?("عربي") || t.include?("Message") && i>100
    # print title
  end
end
# brute find by index 168
[168,165,166,167,168,169,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165].uniq.each do |idx|
  next if idx >= scripts.size
  e = scripts[idx]
  t = e[1]
  comp = e[2]
  begin; content = Zlib::Inflate.inflate(comp); rescue; content = comp; end
  content = content.force_encoding("UTF-8") rescue content
  # sanitize to avoid bad char
  content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  puts "\n\n======== SCRIPT idx=#{idx} id=#{e[0]} title=#{t.inspect} len=#{content.length} ========"
  puts content[0,12000]
  puts "\n======== END #{idx} ========"
end
# also dump first few scripts titles correctly
puts "\n\n=== TITLES 150-170 ==="
(150..169).each do |i|
  next if i>=scripts.size
  t = scripts[i][1].encode("UTF-8", invalid: :replace, undef: :replace) rescue scripts[i][1].inspect
  puts "#{i}: #{t.inspect} len #{scripts[i][2].bytesize}"
end

# dump CE201
puts "\n\n=== CE201 dump ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
ce = arr[201] rescue nil
if ce
  id = ce.instance_variable_get(:@id) rescue "?"
  name = ce.instance_variable_get(:@name) rescue "?"
  puts "CE201 id=#{id} name=#{name.inspect} trigger=#{ce.instance_variable_get(:@trigger) rescue '?'} len=#{ce.instance_variable_get(:@list).size rescue '?'}"
  list = ce.instance_variable_get(:@list) rescue []
  list.each_with_index do |cmd, ci|
    code = cmd.instance_variable_get(:@code) rescue "?"
    params = cmd.instance_variable_get(:@parameters) rescue []
    indent = cmd.instance_variable_get(:@indent) rescue 0
    puts "[#{ci}] indent#{indent} code#{code} #{params.inspect[0,600]}"
  end
end
# also CE74 full
puts "\n\n=== CE74 full ==="
ce74 = arr[74]
if ce74
  puts "CE74 id=#{ce74.instance_variable_get(:@id)} name=#{ce74.instance_variable_get(:@name).inspect}"
  list = ce74.instance_variable_get(:@list)
  list.each_with_index do |cmd,ci|
    code = cmd.instance_variable_get(:@code) rescue "?"
    params = cmd.instance_variable_get(:@parameters) rescue []
    indent = cmd.instance_variable_get(:@indent) rescue 0
    # decode 401 as text snippet
    if code==401
      txt = params[0].to_s.encode("UTF-8", invalid: :replace, undef: :replace)[0,100]
      puts "[#{ci}] code401 #{txt.inspect}"
    else
      puts "[#{ci}] code#{code} #{params.inspect[0,500]}"
    end
  end
end
