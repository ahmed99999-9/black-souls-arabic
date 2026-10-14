# encoding: utf-8
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
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

pics = Dir["Graphics/Pictures/*"].map { |p| File.basename(p, ".*").downcase }
puts "pictures on disk: #{pics.size}"

puts "\n=== CommonEvents: 221/222 fade balance + ShowPicture refs ==="
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue []
    codes = list.map { |c| (c.instance_variable_get(:@code) rescue nil) }
    has_out = codes.include?(221)
    has_in = codes.include?(222)
    name = (ce.instance_variable_get(:@name) rescue "?").to_s
    name = name.dup.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "?") rescue name
    flag = []
    flag << "FADEOUT-NO-FADEIN" if has_out && !has_in
    # missing pics
    list.each do |cmd|
      next unless (cmd.instance_variable_get(:@code) rescue nil) == 231
      params = cmd.instance_variable_get(:@parameters) rescue []
      n = params[1].to_s
      next if n.empty?
      unless pics.include?(n.downcase)
        flag << "MISSING-PIC #{n.inspect}"
      end
    end
    next if flag.empty?
    puts "CE#{idx} '#{name[0, 45]}' #{flag.uniq.join(' | ')}"
  end
rescue => e
  puts "CE err: #{e.class}: #{e.message[0,200]}"
end

puts "\n=== Map events: 221/222 balance per page ==="
bad = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  ((obj.instance_variable_get(:@events) rescue {}) || {}).each do |eid, ev|
    (ev.instance_variable_get(:@pages) rescue []).each_with_index do |pg, pi|
      list = pg.instance_variable_get(:@list) rescue []
      codes = list.map { |c| (c.instance_variable_get(:@code) rescue nil) }
      next unless codes.include?(221)
      next if codes.include?(222)
      bad += 1
      name = (ev.instance_variable_get(:@name) rescue "?").to_s
      puts "  #{File.basename(path)} ev#{eid} pg#{pi} '#{name[0,30]}'"
      break if bad >= 30
    end
  end
  break if bad >= 30
end
puts "total: #{bad}"

puts "\n=== Map events: ShowPicture missing on disk ==="
miss = Hash.new(0)
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj = Marshal.load(File.binread(path)); rescue; next; end
  ((obj.instance_variable_get(:@events) rescue {}) || {}).each do |eid, ev|
    (ev.instance_variable_get(:@pages) rescue []).each do |pg|
      (pg.instance_variable_get(:@list) rescue []).each do |cmd|
        next unless (cmd.instance_variable_get(:@code) rescue nil) == 231
        params = cmd.instance_variable_get(:@parameters) rescue []
        n = params[1].to_s
        next if n.empty?
        unless pics.include?(n.downcase)
          miss[n] += 1
        end
      end
    end
  end
end
miss.sort_by { |k, v| -v }.first(30).each do |k, v|
  puts "  #{v.to_s.rjust(3)}  #{k.inspect}"
end
puts "total missing refs: #{miss.values.inject(0) { |s, v| s + v }}"

# Audio references check (BGM/BGS/SE/ME names) - existence in Audio folders
puts "\n=== Audio file reference check (CommonEvents) ==="
audio_miss = Hash.new(0)
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    (ce.instance_variable_get(:@list) rescue []).each do |cmd|
      code = cmd.instance_variable_get(:@code) rescue nil
      params = cmd.instance_variable_get(:@parameters) rescue []
      case code
      when 241, 245, 249, 250
        af = params[0]
        nm = (af.instance_variable_get(:@name) rescue "") || ""
        next if nm.nil? || nm.empty?
        folder = case code
                 when 241 then "Audio/BGM"
                 when 245 then "Audio/BGS"
                 when 249 then "Audio/ME"
                 when 250 then "Audio/SE"
                 end
        unless Dir["#{folder}/#{nm}.*"].any?
          audio_miss[nm] += 1
        end
      end
    end
  end
rescue => e
  puts "audio err: #{e}"
end
audio_miss.sort_by { |k, v| -v }.first(30).each do |k, v|
  puts "  #{v.to_s.rjust(3)}  #{k.inspect}"
end
puts "total missing audio refs: #{audio_miss.values.inject(0) { |s, v| s + v }}"
