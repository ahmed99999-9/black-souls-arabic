# encoding: utf-8
class Table
  def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end
  def _dump(l); @_raw||""; end
end
class Color
  def self._load(s); allocate; end
  def _dump(l); ""; end
  def initialize(*a); end
end
class Tone
  def self._load(s); allocate; end
  def _dump(l); ""; end
  def initialize(*a); end
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

puts "=== ShowPicture raw params in CommonEvents ==="
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    (ce.instance_variable_get(:@list) rescue []).each do |cmd|
      next unless (cmd.instance_variable_get(:@code) rescue nil) == 231
      params = cmd.instance_variable_get(:@parameters) rescue []
      name = params[1].to_s
      next if name.empty?
      next unless %w[black].include?(name.downcase) || idx == 74 || idx == 75
      puts "CE#{idx} #{params.inspect[0, 160]}"
    end
  end
rescue => e
  puts "CE err: #{e.class}: #{e.message[0,200]}"
end

puts
puts "=== ShowPicture raw params in map events (unique param signatures) ==="
sigs = Hash.new(0)
examples = {}
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  ((obj.instance_variable_get(:@events) rescue {}) || {}).each do |eid, ev|
    (ev.instance_variable_get(:@pages) rescue []).each do |pg|
      (pg.instance_variable_get(:@list) rescue []).each do |cmd|
        next unless (cmd.instance_variable_get(:@code) rescue nil) == 231
        params = cmd.instance_variable_get(:@parameters) rescue []
        name = params[1].to_s
        next if name.empty?
        sig = params.inspect
        sigs[sig] += 1
        examples[sig] ||= "#{File.basename(path)} ev#{eid}"
      end
    end
  end
end
sigs.sort_by { |k, v| -v }.first(25).each do |k, v|
  puts "  #{v.to_s.rjust(4)}  #{k[0, 130]}  (first: #{examples[k]})"
end

puts
puts "=== Enemy events: full page structure for a few ==="
Dir["Data/Map*.rvdata2"].sort.first(3).each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  ((obj.instance_variable_get(:@events) rescue {}) || {}).each do |eid, ev|
    pages = ev.instance_variable_get(:@pages) rescue []
    next if pages.empty?
    l0 = (pages[0].instance_variable_get(:@list) rescue [])
    next unless l0.any? { |c| (c.instance_variable_get(:@code) rescue nil) == 301 }
    name = (ev.instance_variable_get(:@name) rescue "?").to_s
    puts "\n--- #{File.basename(path)} ev#{eid} '#{name[0,40]}' pages=#{pages.size} ---"
    pages.each_with_index do |pg, pi|
      trig = pg.instance_variable_get(:@trigger) rescue nil
      cond = pg.instance_variable_get(:@condition) rescue nil
      ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
      gfx = pg.instance_variable_get(:@graphic) rescue nil
      gname = (gfx.instance_variable_get(:@character_name) rescue "") || ""
      list = pg.instance_variable_get(:@list) rescue []
      puts " pg#{pi} trig=#{trig} self=#{ch.inspect} gfx=#{gname.inspect[0,30]}"
      list.each do |cmd|
        code = cmd.instance_variable_get(:@code) rescue nil
        params = cmd.instance_variable_get(:@parameters) rescue []
        case code
        when 301
          puts "   [301] battle #{params[0, 3].inspect} #{params[3].inspect if params[3]}"
        when 601, 603, 604
          puts "   [#{code}] branch"
        when 123
          puts "   [123] self-switch #{params.inspect}"
        when 205
          mr = params[1]
          steps = (mr.instance_variable_get(:@list) rescue []).map { |mc| "#{mc.instance_variable_get(:@code)}:#{(mc.instance_variable_get(:@parameters) rescue []).inspect[0,50]}" }
          puts "   [205] move route wait=#{(mr.instance_variable_get(:@wait) rescue nil)} steps=#{steps.join(' | ')[0,200]}"
        when 122
          puts "   [122] var #{params[0, 4].inspect}"
        when 121
          puts "   [121] switch #{params.inspect[0,60]}"
        when 108, 408
          t = params[0].to_s
          puts "   [#{code}] comment #{t[0,60].inspect}" unless t.strip.empty?
        when 117
          puts "   [117] call CE #{params.inspect}"
        when 101, 401
          t = params[0].to_s
          puts "   [#{code}] text #{t[0,40].inspect}"
        when 221, 222, 223, 230
          puts "   [#{code}] #{params.inspect[0,60]}"
        end
      end
    end
  end
end
