#!/usr/bin/env ruby
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
# encoding: utf-8
# Explicit stubs for RPG Maker VX Ace Marshal

class Table
  def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end
  def _dump(lvl); @_raw||""; end
end
class Color
  def self._load(s); allocate; end
  def _dump(lvl); ""; end
  def initialize(*a); end
end
class Tone
  def self._load(s); allocate; end
  def _dump(lvl); ""; end
  def initialize(*a); end
end

module RPG
  class Map
    attr_accessor :display_name,:tileset_id,:width,:height,:scroll_type,:specify_battleback,
      :battleback1_name,:battleback2_name,:autoplay_bgm,:bgm,:autoplay_bgs,:bgs,
      :disable_dashing,:encounter_list,:encounter_step,:parallax_name,:parallax_loop_x,
      :parallax_loop_y,:parallax_sx,:parallax_sy,:parallax_show,:note,:data,:events
    class Encounter; attr_accessor :troop_id,:weight,:region_set; end
  end
  class MapInfo; attr_accessor :name,:parent_id,:order,:expanded,:scroll_x,:scroll_y; end
  class Event
    attr_accessor :id,:name,:x,:y,:pages
    class Page
      attr_accessor :condition,:graphic,:move_type,:move_speed,:move_frequency,:move_route,
        :walk_anime,:step_anime,:direction_fix,:through,:priority_type,:trigger,:list
      class Condition
        attr_accessor :switch1_valid,:switch2_valid,:variable_valid,:self_switch_valid,
          :item_valid,:actor_valid,:switch1_id,:switch2_id,:variable_id,:variable_value,
          :self_switch_ch,:item_id,:actor_id
      end
      class Graphic
        attr_accessor :tile_id,:character_name,:character_index,:direction,:pattern
      end
    end
  end
  class MoveRoute; attr_accessor :repeat,:skippable,:wait,:list; end
  class MoveCommand; attr_accessor :code,:parameters; end
  class EventCommand; attr_accessor :code,:indent,:parameters; end
  class CommonEvent; attr_accessor :id,:name,:trigger,:switch_id,:list; end
  class System; end
  class Troop; class Page; end; end
  class Actor; end; class Class; end; class Skill; end; class Item; end
  class Weapon; end; class Armor; end; class Enemy; end; class State; end
  class Animation; end; class Tileset; end; class AudioFile; end
  class BGM; attr_accessor :name,:volume,:pitch; end
  class BGS; attr_accessor :name,:volume,:pitch; end
  class SE; attr_accessor :name,:volume,:pitch; end
  class ME; attr_accessor :name,:volume,:pitch; end
end

ok=0; fail=0
bad_self=[]
bad123=[]
# MapInfos is not a Map — skip it
Dir.glob("Data/Map*.rvdata2").sort.reject{|p| p.include?("MapInfos")}.each do |path|
  mid=File.basename(path)
  begin
    obj=Marshal.load(File.binread(path))
  rescue => e
    fail+=1
    puts "FAIL #{mid}: #{e.class}: #{e.message[0,150]}"
    next
  end
  ok+=1
  (obj.events||{}).each do |id, ev|
    next unless ev && ev.pages
    ev.pages.each_with_index do |pg, pi|
      c=pg.condition
      if c && c.self_switch_valid && c.self_switch_ch !~ /\A[A-D]\z/
        bad_self << [mid,id,pi,c.self_switch_ch.inspect]
      end
      (pg.list||[]).each do |cmd|
        if cmd.code==123
          ch=cmd.parameters[0]
          bad123 << [mid,id,pi,ch.inspect] if ch !~ /\A[A-D]\z/
        end
      end
    end
  end
end
puts "OK=#{ok} FAIL=#{fail}"
puts "BAD self_switch_ch: #{bad_self.size}"
bad_self.first(20).each{|r| puts "  #{r.inspect}"}
puts "BAD 123: #{bad123.size}"
bad123.first(20).each{|r| puts "  #{r.inspect}"}

# Picture check
pics = Dir.glob("Graphics/Pictures/*").map{|p| File.basename(p).downcase}
missing=[]
refs={}
Dir.glob("Data/Map*.rvdata2").sort.reject{|p| p.include?("MapInfos")}.each do |path|
  obj=Marshal.load(File.binread(path)) rescue next
  mid=File.basename(path)
  (obj.events||{}).each do |id, ev|
    next unless ev
    (ev.pages||[]).each_with_index do |pg,pi|
      (pg.list||[]).each do |cmd|
        next unless cmd.code==231
        name=cmd.parameters[1]
        next if name.nil?||name.empty?
        next unless name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length<40
        key=name.downcase
        refs[key]=true
        unless pics.include?(key+".png")||pics.include?(key+".jpg")||pics.include?(key)
          missing<<[mid,id,pi,name]
        end
      end
    end
  end
end
# CommonEvents
begin
  arr=Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    (ce.list||[]).each do |cmd|
      next unless cmd.code==231
      name=cmd.parameters[1]
      next if name.nil?||name.empty?
      next unless name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length<40
      key=name.downcase
      refs[key]=true
      unless pics.include?(key+".png")||pics.include?(key+".jpg")
        missing<<["CommonEvents[#{idx}]",0,0,name]
      end
      # check long names
      if name.length>80
        puts "LONG ShowPicture CommonEvents[#{idx}]: #{name.inspect[0,150]}"
      end
    end
    (ce.list||[]).each do |cmd|
      if cmd.code==123 && cmd.parameters[0] !~ /\A[A-D]\z/
        puts "CommonEvents[#{idx}] BAD 123 #{cmd.parameters.inspect}"
      end
    end
  end
rescue=>e
  puts "CommonEvents: #{e.class}: #{e.message[0,200]}"
end
puts "Distinct refs: #{refs.size}  Missing: #{missing.size}"
missing.first(20).each{|m| puts " MISSING #{m.inspect}"}
puts "Pics on disk: #{pics.size}"

# Enemy body dump: first 3 maps with BattleProcessing
puts "\n=== Enemy body pages ==="
Dir.glob("Data/Map*.rvdata2").sort.reject{|p| p.include?("MapInfos")}.first(8).each do |path|
  obj=Marshal.load(File.binread(path)) rescue next
  mid=File.basename(path)
  (obj.events||{}).each do |id, ev|
    next unless ev
    pages=ev.pages||[]
    next if pages.empty?
    has301 = pages[0].list.any?{|c| c.code==301} rescue false
    next unless has301
    puts "\n#{mid} ev#{id} (#{ev.name.inspect[0,30]}) x=#{ev.x} y=#{ev.y} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      c=pg.condition
      cstr = c && c.self_switch_valid ? " Self#{c.self_switch_ch}" : ""
      gname = pg.graphic ? pg.graphic.character_name.inspect[0,30] : "nil"
      codes = (pg.list||[]).map{|cc| cc.code}.join(",")
      puts " pg#{pi} trig=#{pg.trigger}#{cstr} gfx=#{gname} codes=[#{codes[0,120]}]"
      (pg.list||[]).each do |cmd|
        if cmd.code==205
          mr=cmd.parameters[1]
          if mr && mr.list
            steps=mr.list.map{|mc| "#{mc.code}:#{mc.parameters.inspect[0,40]}"}.join(" | ")
            puts "   205 MoveRoute wait=#{mr.wait} steps=#{steps[0,250]}"
          end
        end
      end
    end
  end
end
