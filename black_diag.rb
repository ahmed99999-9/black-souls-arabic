#!/usr/bin/env ruby
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
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
puts "total CE #{arr.size} non-nil #{arr.compact.size}"
arr.each_with_index do |ce, idx|
  next unless ce
  list = ce.instance_variable_get(:@list)
  next unless list
  has_black = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==231 && (c.instance_variable_get(:@parameters)[1] rescue "")=="black"}
  has_any_pic = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==231}
  next unless has_black || (has_any_pic && idx.between?(74,145))
  name = ce.instance_variable_get(:@name)
  id = ce.instance_variable_get(:@id)
  trig = ce.instance_variable_get(:@trigger)
  sw = ce.instance_variable_get(:@switch_id)
  puts "\n===CE idx#{idx} id=#{id} name=#{name.inspect} trig=#{trig} sw=#{sw} len=#{list.size} has_black=#{has_black}==="
  list.each_with_index do |cmd, ci|
    code = cmd.instance_variable_get(:@code) rescue nil
    params = cmd.instance_variable_get(:@parameters) rescue nil
    indent = cmd.instance_variable_get(:@indent) rescue 0
    next if ci>80 && code!=235
    if code==231
      puts "[#{ci}] indent#{indent} 231 ShowPicture num=#{params[0]} name=#{params[1].inspect} origin=#{params[2]} type=#{params[3]} x=#{params[4]} y=#{params[5]} zoom=#{params[6]},#{params[7]} opacity=#{params[8]} blend=#{params[9]}"
    elsif code==232
      puts "[#{ci}] indent#{indent} 232 MovePicture #{params.inspect[0,500]}"
    elsif code==235
      puts "[#{ci}] indent#{indent} 235 ErasePicture num=#{params[0].inspect}"
    elsif code==223
      tone=params[0]
      r=tone.instance_variable_get(:@red) rescue "?"; g=tone.instance_variable_get(:@green) rescue "?"; b=tone.instance_variable_get(:@blue) rescue "?"; gr=tone.instance_variable_get(:@gray) rescue "?"
      puts "[#{ci}] indent#{indent} 223 Tint tone=#{r},#{g},#{b},#{gr} dur=#{params[1]} wait=#{params[2]}"
    else
      if [221,222,224,250,251,236,101,401,102,402,404,108,408,121,122,123,117].include?(code) || ci<7
        puts "[#{ci}] indent#{indent} code#{code} #{params.inspect[0,500]}"
      end
    end
  end
end
puts "\n\n===Maps with ShowPicture black==="
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = obj.instance_variable_get(:@events) rescue nil; next unless events
  events.each do |eid, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) rescue nil; next unless pages
    pages.each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue nil; next unless list
      has = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==231 && (c.instance_variable_get(:@parameters)[1] rescue "")=="black"}
      next unless has
      puts "#{File.basename(path)} ev#{eid} '#{(ev.instance_variable_get(:@name) rescue '?')[0,30]}' pg#{pi} trig=#{pg.instance_variable_get(:@trigger) rescue '?'}"
      list.each_with_index do |cmd, ci|
        code=cmd.instance_variable_get(:@code) rescue nil
        params=cmd.instance_variable_get(:@parameters) rescue nil
        indent=cmd.instance_variable_get(:@indent) rescue 0
        if [231,235,221,222].include?(code)
          puts " [#{ci}] code#{code} #{params.inspect[0,500]}"
        end
      end
    end
  end
end
# Check black.png existence
puts "\n===Check black.png existence==="
puts "exists Graphics/Pictures/black.png ? #{File.exist?('Graphics/Pictures/black.png')}"
puts "exists Graphics/Pictures/black ? #{File.exist?('Graphics/Pictures/black')}"
puts "ls pics grep black: #{Dir['Graphics/Pictures/*'].select{|f| f.downcase.include?('black')}.join(', ')}"
puts "all pics count #{Dir['Graphics/Pictures/*'].size}"
puts "pics lowercase list includes 'black'? #{Dir['Graphics/Pictures/*'].map{|p| File.basename(p,'.*').downcase }.include?('black')}"
# Also check case where black is uppercase? no
# Dump first CE with black fully for analysis
puts "\n\n===First CE with black full 0..30==="
first = arr.index{|ce| ce && (ce.instance_variable_get(:@list).any?{|c| (c.instance_variable_get(:@code) rescue nil)==231 && (c.instance_variable_get(:@parameters)[1] rescue '')=='black'} rescue false)}
if first
  ce=arr[first]
  list=ce.instance_variable_get(:@list)
  name=ce.instance_variable_get(:@name)
  puts "CE #{first} id=#{ce.instance_variable_get(:@id)} name=#{name.inspect}"
  list.first(35).each_with_index do |cmd, ci|
    code=cmd.instance_variable_get(:@code) rescue nil
    params=cmd.instance_variable_get(:@parameters) rescue nil
    puts "[#{ci}] code#{code} #{params.inspect[0,700]}"
  end
end
