# encoding: utf-8
class Table
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
class Color
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
class Tone
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
end
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
require "zlib"

def code(c); c.instance_variable_get(:@code) rescue nil; end
def params(c); c.instance_variable_get(:@parameters) rescue []; end
def events_of(obj); (obj.instance_variable_get(:@events) rescue {}) || {}; end
def pages_of(ev); (ev.instance_variable_get(:@pages) rescue []) || []; end
def list_of(pg); (pg.instance_variable_get(:@list) rescue []) || []; end

puts "=== 1. CE201 fade balance ==="
arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
ce = arr[201]
list = list_of(ce)
codes = list.map { |c| code(c) }
puts "  CE201: 221=#{codes.count(221)} 222=#{codes.count(222)} 201=#{codes.count(201)}"
list.each_with_index do |c, i|
  c_ = code(c)
  if [221, 222, 201, 0].include?(c_)
    puts "   [#{i}] #{c_} #{params(c).inspect[0, 60]}"
  end
end

puts
puts "=== 2. Enemy death pages now erase ==="
total_enemies = 0
d_erase = 0
b_erase = 0
d_empty = 0
d_other = 0
enemies_no_d = 0
suspicious = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = Marshal.load(File.binread(path))
  events_of(obj).each do |eid, ev|
    pages = pages_of(ev)
    next if pages.empty?
    l0 = list_of(pages[0])
    next unless l0.any? { |c| code(c) == 301 }
    total_enemies += 1
    has_d = false
    pages[1..-1].each do |pg|
      cond = pg.instance_variable_get(:@condition) rescue nil
      ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
      valid = cond.instance_variable_get(:@self_switch_valid) rescue false
      next unless valid
      l = list_of(pg)
      has214 = l.any? { |c| code(c) == 214 }
      gfx = pg.instance_variable_get(:@graphic) rescue nil
      gname = (gfx.instance_variable_get(:@character_name) rescue "") || ""
      trig = pg.instance_variable_get(:@trigger) rescue nil
      if ch == "D"
        has_d = true
        if has214
          d_erase += 1
        elsif gname.empty? && l.all? { |c| code(c) == 0 }
          d_empty += 1
        else
          d_other += 1
          suspicious << "#{File.basename(path)} ev#{eid} pg codes=#{l.map { |c| code(c) }.join(',')}"
        end
      elsif ch == "B" && has214
        b_erase += 1
      end
    end
    enemies_no_d += 1 unless has_d
  end
end
puts "  total enemy events: #{total_enemies}"
puts "  D pages rewritten to erase: #{d_erase}"
puts "  D pages empty (already invisible): #{d_empty}"
puts "  D pages OTHER (not rewritten): #{d_other}"
puts "  B pages rewritten to erase: #{b_erase}"
puts "  enemies with no D page: #{enemies_no_d}"
suspicious.first(10).each { |s| puts "    OTHER: #{s}" }

puts
puts "=== 3. Erase-event pages belong only to enemy B/D pages ==="
bad = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = Marshal.load(File.binread(path))
  events_of(obj).each do |eid, ev|
    pages = pages_of(ev)
    pages.each_with_index do |pg, pi|
      l = list_of(pg)
      next unless l.any? { |c| code(c) == 214 }
      is_enemy = false
      if pi > 0
        l0 = list_of(pages[0])
        is_enemy = l0.any? { |c| code(c) == 301 }
        cond = pg.instance_variable_get(:@condition) rescue nil
        ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
        valid = cond.instance_variable_get(:@self_switch_valid) rescue false
        is_enemy = is_enemy && valid && (ch == "D" || ch == "B")
      end
      bad << "#{File.basename(path)} ev#{eid} pg#{pi}" unless is_enemy
    end
  end
end

puts
puts "=== 3b. Enemies without D page: do they erase via B? ==="
no_d = 0
no_d_covered = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = Marshal.load(File.binread(path))
  events_of(obj).each do |eid, ev|
    pages = pages_of(ev)
    next if pages.empty?
    l0 = list_of(pages[0])
    next unless l0.any? { |c| code(c) == 301 }
    has_d = false
    has_b_erase = false
    pages[1..-1].each do |pg|
      cond = pg.instance_variable_get(:@condition) rescue nil
      ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
      valid = cond.instance_variable_get(:@self_switch_valid) rescue false
      next unless valid
      has_d = true if ch == "D"
      if ch == "B" && list_of(pg).any? { |c| code(c) == 214 }
        has_b_erase = true
      end
    end
    next if has_d
    no_d += 1
    no_d_covered += 1 if has_b_erase
  end
end
puts "  no-D enemies: #{no_d}, of which erase via B page: #{no_d_covered}"
puts bad.empty? ? "  all 214 pages are on enemy B/D pages" : "  LEAK: #{bad.first(10).join(', ')}"

puts
puts "=== 4. Scripts.rvdata2 guard ==="
scripts = Marshal.load(File.binread("Data/Scripts.rvdata2"))
idx = scripts.index { |s| s[1].to_s.include?("Window Title") }
text = Zlib::Inflate.inflate(scripts[idx][2]).force_encoding("UTF-8")
puts "  Win32API guard present: #{text.include?('defined?(Win32API)')}"
puts "  nil-handle guard present: #{text.include?('return unless defined?(FindWindow)')}"
puts "  title constant kept: #{text.include?('النفوس السوداء')}"

puts
puts "=== 5. Stability round-trip of edited files ==="
fail_count = 0
(Dir["Data/Map*.rvdata2"].sort + ["Data/CommonEvents.rvdata2", "Data/Scripts.rvdata2"]).each do |f|
  obj = Marshal.load(File.binread(f))
  tmp = "/tmp/st_#{File.basename(f)}"
  File.binwrite(tmp, Marshal.dump(obj))
  fail_count += 1 if File.binread(tmp) != File.binread(f)
end
puts fail_count.zero? ? "  all files stable (load-dump identical)" : "  #{fail_count} unstable files"
