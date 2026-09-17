# encoding: utf-8
# Analyze enemy death pages + fade balance.
class Table
  def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end
  def _dump(l); @_raw||""; end
end
class Color; def initialize(*a); end; end
class Tone; def initialize(*a); end; end
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

def get_events(obj); (obj.instance_variable_get(:@events) rescue {}) || {}; end
def get_pages(ev); ev.instance_variable_get(:@pages) rescue []; end
def get_list(pg); pg.instance_variable_get(:@list) rescue []; end
def get_cond(pg); pg.instance_variable_get(:@condition) rescue nil; end
def get_gfx(pg); pg.instance_variable_get(:@graphic) rescue nil; end

# Allowed by death_animation_page? in Battle Body Fix 5
ALLOWED = [0, 205, 505, 123, 108, 408, 132]

puts "=== ENEMY DEATH PAGE ANALYSIS ==="
stats = Hash.new(0)
examples = {}
total_enemies = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  get_events(obj).each do |eid, ev|
    pages = get_pages(ev)
    next if pages.empty?
    l0 = get_list(pages[0])
    next unless l0.any? { |c| (c.instance_variable_get(:@code) rescue nil) == 301 }
    total_enemies += 1
    pages[1..-1].each_with_index do |pg, i|
      pi = i + 1
      cond = get_cond(pg)
      ch = (cond.instance_variable_get(:@self_switch_ch) rescue nil)
      trig = (pg.instance_variable_get(:@trigger) rescue nil)
      gfx = get_gfx(pg)
      gname = (gfx.instance_variable_get(:@character_name) rescue "") || ""
      list = get_list(pg)
      codes = list.map { |c| (c.instance_variable_get(:@code) rescue nil) }
      # classify
      ok_trig = trig == 4
      ok_codes = codes.all? { |c| ALLOWED.include?(c) }
      death_anim = ok_trig && ok_codes
      key = "trig#{trig} ch=#{ch} gfx=#{gname.empty? ? 'none' : 'char'} codes=#{codes.uniq.sort.join(',')}"
      stats[key] += 1
      if !death_anim && (examples[key] rescue nil).nil?
        examples[key] = [File.basename(path), eid, pi]
      end
      # Detailed look at a few non-matching death pages
      if !death_anim && (examples[key] rescue nil)
        # print move routes of first example of each non-matching pattern
      end
    end
  end
end
puts "total enemy events: #{total_enemies}"
stats.sort_by { |k, v| -v }.each do |k, v|
  puts "  #{v.to_s.rjust(4)}  #{k}"
end

puts
puts "=== First example of each non-matching death page pattern ==="
examples.each do |k, v|
  puts "  #{k}  ->  #{v.inspect}"
end

# Fade balance across CommonEvents
puts
puts "=== CommonEvents with 221 FadeOut but no 222 FadeIn ==="
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue []
    codes = list.map { |c| (c.instance_variable_get(:@code) rescue nil) }
    next unless codes.include?(221)
    name = (ce.instance_variable_get(:@name) rescue "?").to_s
    has_in = codes.include?(222)
    puts "CE#{idx} name=#{name[0, 50].inspect} 221=#{codes.count(221)} 222=#{codes.count(222)} #{has_in ? '' : '<-- NO FADEIN'}"
  end
rescue => e
  puts "CE err: #{e}"
end

# Fade balance across map event pages
puts
puts "=== Map event pages with 221 but no 222 (sample up to 40) ==="
count = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  get_events(obj).each do |eid, ev|
    get_pages(ev).each_with_index do |pg, pi|
      list = get_list(pg)
      codes = list.map { |c| (c.instance_variable_get(:@code) rescue nil) }
      next unless codes.include?(221)
      next if codes.include?(222)
      count += 1
      if count <= 40
        name = (ev.instance_variable_get(:@name) rescue "?").to_s
        puts "  #{File.basename(path)} ev#{eid} pg#{pi} name=#{name[0,30].inspect}"
      end
    end
  end
end
puts "total pages fadeout-without-fadein: #{count}"

# picture refs check across common events
puts
puts "=== ShowPicture refs in CommonEvents missing on disk ==="
pics = Dir["Graphics/Pictures/*"].map { |p| File.basename(p, ".*").downcase }
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    (ce.instance_variable_get(:@list) rescue []).each do |cmd|
      next unless (cmd.instance_variable_get(:@code) rescue nil) == 231
      params = cmd.instance_variable_get(:@parameters) rescue []
      n = params[1].to_s
      next if n.empty?
      unless pics.include?(n.downcase)
        puts "  CommonEvents[#{idx}] missing pic #{n.inspect}"
      end
    end
  end
rescue => e
  puts "pic err: #{e}"
end
