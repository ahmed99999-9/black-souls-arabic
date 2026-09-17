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
def indent(c); c.instance_variable_get(:@indent) rescue 0; end
def events_of(obj); (obj.instance_variable_get(:@events) rescue {}) || {}; end
def pages_of(ev); (ev.instance_variable_get(:@pages) rescue []) || []; end
def list_of(pg); (pg.instance_variable_get(:@list) rescue []) || []; end

# Track which branch (601 win / 602 escape / 603 lose / 604 abort) a 123 command sits in
def branches_for(list)
  branches = []
  current = nil
  list.each do |c|
    cc = code(c)
    ic = indent(c)
    case cc
    when 601, 602, 603, 604
      current = [cc, ic]
      branches << current
    when 412 # end branch
      current = nil
    when 123
      next unless current
      p = params(c)
      next unless p && p[1] == 0 # ON
      branches << [current[0], current[1], p[0]]
    end
  end
  branches
end

puts "=== How enemies set self-switch D and B ==="
stats = Hash.new(0)
victory_b = []
victory_d = []
escape_b = []
no_self_set = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = Marshal.load(File.binread(path))
  events_of(obj).each do |eid, ev|
    pages = pages_of(ev)
    next if pages.empty?
    l0 = list_of(pages[0])
    next unless l0.any? { |c| code(c) == 301 }
    br = branches_for(l0)
    d_win = br.any? { |b| b[0] == 601 && b[2] == "D" }
    b_win = br.any? { |b| b[0] == 601 && b[2] == "B" }
    b_esc = br.any? { |b| b[0] == 602 && b[2] == "B" }
    d_esc = br.any? { |b| b[0] == 602 && b[2] == "D" }
    key = "D#{d_win ? 'W' : '-'}#{d_esc ? 'E' : '-'} B#{b_win ? 'W' : '-'}#{b_esc ? 'E' : '-'}"
    stats[key] += 1
    victory_d << "#{File.basename(path)} ev#{eid}" if d_win
    victory_b << "#{File.basename(path)} ev#{eid}" if b_win
    escape_b << "#{File.basename(path)} ev#{eid}" if b_esc
    no_self_set << "#{File.basename(path)} ev#{eid}" if br.none? { |b| b.size == 3 }
  end
end
stats.sort_by { |k, v| -v }.each { |k, v| puts "  #{v.to_s.rjust(4)}  #{k}" }
puts "  victory sets D: #{victory_d.size}"
puts "  victory sets B: #{victory_b.size}"
puts "  escape sets B: #{escape_b.size}"
puts "  no self-switch set at all: #{no_self_set.size}"
puts "  enemies that set B on victory but NOT D on victory: #{(victory_b - victory_d).size}"
puts "    first 10: #{(victory_b - victory_d).first(10).join(', ')}"
puts "  enemies that set B on escape: #{escape_b.size}"
puts "    first 10: #{escape_b.first(10).join(', ')}"
