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

def code(c); c.instance_variable_get(:@code) rescue nil; end
def params(c); c.instance_variable_get(:@parameters) rescue []; end
def events_of(obj); (obj.instance_variable_get(:@events) rescue {}) || {}; end
def pages_of(ev); (ev.instance_variable_get(:@pages) rescue []) || []; end
def list_of(pg); (pg.instance_variable_get(:@list) rescue []) || []; end

puts "=== Enemy events WITHOUT a D page: full page structure ==="
shown = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = Marshal.load(File.binread(path))
  events_of(obj).each do |eid, ev|
    pages = pages_of(ev)
    next if pages.empty?
    l0 = list_of(pages[0])
    next unless l0.any? { |c| code(c) == 301 }
    has_d = pages[1..-1].any? do |pg|
      cond = pg.instance_variable_get(:@condition) rescue nil
      (cond.instance_variable_get(:@self_switch_valid) rescue false) &&
        (cond.instance_variable_get(:@self_switch_ch) rescue nil) == "D"
    end
    next if has_d
    name = (ev.instance_variable_get(:@name) rescue "?").to_s
    puts "\n--- #{File.basename(path)} ev#{eid} '#{name[0,40]}' pages=#{pages.size} ---"
    pages.each_with_index do |pg, pi|
      trig = pg.instance_variable_get(:@trigger) rescue nil
      cond = pg.instance_variable_get(:@condition) rescue nil
      ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
      valid = cond.instance_variable_get(:@self_switch_valid) rescue false
      sw1 = cond.instance_variable_get(:@switch1_valid) rescue false
      sw1id = cond.instance_variable_get(:@switch1_id) rescue nil
      gfx = pg.instance_variable_get(:@graphic) rescue nil
      gname = (gfx.instance_variable_get(:@character_name) rescue "") || ""
      l = list_of(pg)
      codes = l.map { |c| code(c) }
      puts " pg#{pi} trig=#{trig} cond=#{valid ? "self#{ch}" : (sw1 ? "sw#{sw1id}" : "-")} gfx=#{gname.empty? ? 'none' : gname.inspect[0,20]} codes=#{codes.join(',')[0,80]}"
    end
    shown += 1
    break if shown >= 25
  end
  break if shown >= 25
end
