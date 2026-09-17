#!/usr/bin/env ruby
# encoding: utf-8
# Auto-stub any missing constant so Marshal can load any RPG Maker file
module AutoStub
  def const_missing(name)
    mod = Module.new
    # make it so nested constants also auto-stub
    mod.extend(AutoStub)
    # also class-like: need to allow instances to have ivars
    cls = Class.new do
      extend AutoStub
      def initialize(*a); end
    end
    # Prefer class if name looks like a class (capitalized), else module
    # But we return a Class for anything that Marshal tries to allocate
    c = Class.new do
      extend AutoStub
    end
    const_set(name, c)
    c
  end
end
Module.extend(AutoStub)
class Object
  extend AutoStub
end
# RPG top-level also
module RPG
  extend AutoStub
end
# Specific expected classes: define properly to hold data
class Table
  def self._load(s)
    o = allocate; o.instance_variable_set(:@_raw, s); o
  end
  def _dump(lvl)
    @_raw || ""
  end
end
class Color
  def initialize(*a); @red, @green, @blue, @alpha = a; end
end
class Tone
  def initialize(*a); @red, @green, @blue, @gray = a; end
end

def b2s(b)
  return "" if b.nil?
  return b if b.is_a?(String)
  b.to_s
end

invalid_self = []
bad123 = []
ok_maps = 0
fail_maps = []

Dir.glob("Data/Map*.rvdata2").sort.each do |path|
  mid = File.basename(path)
  begin
    obj = Marshal.load(File.binread(path))
  rescue => e
    fail_maps << [mid, e.class.to_s + ": " + e.message[0,120]]
    next
  end
  ok_maps += 1
  # obj is RPG::Map
  events = obj.instance_variable_get(:@events) rescue {}
  next unless events
  events.each do |id, ev|
    next unless ev
    pages = ev.instance_variable_get(:@pages) || []
    pages.each_with_index do |pg, pi|
      cond = pg.instance_variable_get(:@condition) rescue nil
      if cond
        valid = cond.instance_variable_get(:@self_switch_valid) rescue false
        ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
        if valid && ch !~ /\A[A-D]\z/
          invalid_self << [mid, id, pi, ch.inspect]
        end
      end
      list = pg.instance_variable_get(:@list) || []
      list.each do |cmd|
        next unless cmd
        if cmd.code == 123
          ch = cmd.parameters[0]
          if ch !~ /\A[A-D]\z/
            bad123 << [mid, id, pi, cmd.parameters.inspect[0,80]]
          end
        end
      end
    end
  end
end

puts "OK maps: #{ok_maps}  FAIL: #{fail_maps.size}"
fail_maps.each{|f| puts " FAIL #{f[0]}: #{f[1]}"}
puts "Invalid @self_switch_ch (valid but not A-D): #{invalid_self.size}"
invalid_self.first(30).each{|r| puts "  #{r.inspect}"}
puts "BAD 123 SelfSwitch: #{bad123.size}"
bad123.first(30).each{|r| puts "  #{r.inspect}"}

# ShowPicture check
puts "\n=== ShowPicture check ==="
pics_on_disk = Dir.glob("Graphics/Pictures/*").map{|p| File.basename(p).downcase }
missing = []
refs = {}
Dir.glob("Data/Map*.rvdata2").sort.each do |path|
  obj = Marshal.load(File.binread(path)) rescue next
  mid = File.basename(path)
  (obj.events || {}).each do |id, ev|
    next unless ev
    (ev.pages || []).each_with_index do |pg, pi|
      (pg.list || []).each do |cmd|
        next unless cmd.code == 231
        name = cmd.parameters[1]
        next if name.nil? || name.empty?
        # only count ascii-like picture names (the real pictures)
        if name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length < 40
          key = name.downcase
          refs[key] ||= []
          refs[key] << [mid, id, pi]
          unless pics_on_disk.include?(key + ".png") || pics_on_disk.include?(key + ".jpg") || pics_on_disk.include?(key)
            missing << [mid, id, pi, name]
          end
        elsif name.length > 80
          puts "SUSPICIOUS long ShowPicture #{mid} ev#{id} pg#{pi}: #{name.inspect[0,100]}"
        end
      end
    end
  end
end
# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    (ce.list || []).each do |cmd|
      next unless cmd.code == 231
      name = cmd.parameters[1]
      next if name.nil? || name.empty?
      if name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length < 40
        key = name.downcase
        refs[key] ||= []
        refs[key] << ["CommonEvents[#{idx}]", 0, 0]
        unless pics_on_disk.include?(key + ".png") || pics_on_disk.include?(key + ".jpg")
          missing << ["CommonEvents[#{idx}]", 0, 0, name]
        end
      elsif name.length > 80
        puts "CommonEvents[#{idx}] long ShowPicture: #{name.inspect[0,200]}"
      end
    end
  end
rescue => e
  puts "CommonEvents load fail: #{e.class}: #{e.message[0,200]}"
end
puts "Distinct ASCII picture refs: #{refs.size}"
puts "Missing pictures: #{missing.size}"
missing.first(30).each{|m| puts " MISSING #{m.inspect}"}
puts "Pictures on disk: #{pics_on_disk.size}"

# Enemy body check: every event that has a BattleProcessing (301) on pg0
puts "\n=== Enemy body events (BattleProcessing on pg0) ==="
Dir.glob("Data/Map*.rvdata2").sort.each do |path|
  obj = Marshal.load(File.binread(path)) rescue next
  mid = File.basename(path)
  (obj.events || {}).each do |id, ev|
    next unless ev
    pages = ev.pages || []
    next if pages.empty?
    has301 = pages[0].list.any?{|c| c.code==301 } rescue false
    next unless has301
    puts "\n#{mid} ev#{id} x=#{ev.x} y=#{ev.y} name=#{ev.name.inspect[0,40]} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      cond = pg.condition rescue nil
      trig = pg.trigger rescue "?"
      cstr = ""
      if cond && cond.self_switch_valid
        cstr = " Self#{cond.self_switch_ch}=valid"
      end
      gfx = pg.graphic rescue nil
      gname = gfx ? gfx.character_name.inspect[0,40] : "nil"
      codes = (pg.list || []).map{|c| c.code }.join(",")
      puts "  pg#{pi} trig=#{trig}#{cstr} gfx=#{gname} codes=[#{codes[0,120]}]"
      # dump 123 and 205 details for this page
      (pg.list || []).each do |cmd|
        if cmd.code==123
          puts "    123 SelfSwitch #{cmd.parameters.inspect}"
        elsif cmd.code==205
          mr = cmd.parameters[1]
          if mr
            steps = (mr.list || []).map{|mc| "#{mc.code}:#{mc.parameters.inspect[0,30]}"}.join(" | ")
            puts "    205 MoveRoute wait=#{mr.wait} steps=#{steps[0,200]}"
          end
        elsif cmd.code==214
          puts "    214 EraseEvent"
        end
      end
    end
    # only first few maps
    break if mid=="Map002.rvdata2" && id.to_i>15
  end
end

# Cat scene deep: dump CommonEvents that are picture-based CG
puts "\n=== CommonEvents detailed (picture CG) ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2")) rescue []
arr.each_with_index do |ce, idx|
  next unless ce
  has_pic = (ce.list || []).any?{|c| c.code==231}
  next unless has_pic
  puts "CommonEvents[#{idx}] name=#{ce.name.inspect} trigger=#{ce.trigger} switch=#{ce.switch_id}"
  (ce.list || []).first(40).each do |cmd|
    if [101,401,231,235,232,221,222,223,224,201,205,214,118,119,121,122,123].include?(cmd.code)
      puts "  #{cmd.code} #{cmd.parameters.inspect[0,120]}"
    else
      puts "  #{cmd.code} #{cmd.parameters.inspect[0,80]}"
    end
  end
  puts "  ... total #{ce.list.size} commands"
  break if idx>10 && has_pic
end
