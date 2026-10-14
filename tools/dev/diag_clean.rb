#!/usr/bin/env ruby
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
# encoding: utf-8
module AutoStub
  def const_missing(name)
    c = Class.new do
      extend AutoStub
      def initialize(*a); end
    end
    const_set(name, c)
    c
  end
end
Module.extend(AutoStub)
class Object; extend AutoStub; end
module RPG; extend AutoStub; end
class Table
  def self._load(s); o=allocate; o.instance_variable_set(:@_raw,s); o; end
  def _dump(l); @_raw||""; end
end
class Color; def initialize(*a); end; end
class Tone; def initialize(*a); end; end

require 'zlib'

def get_events(obj)
  return {} unless obj
  if obj.respond_to?(:events)
    begin; return obj.events; rescue; end
  end
  obj.instance_variable_get(:@events) rescue {}
end
def get_pages(ev)
  ev.instance_variable_get(:@pages) rescue (ev.pages rescue [])
end
def get_list(pg)
  pg.instance_variable_get(:@list) rescue (pg.list rescue [])
end
def get_cond(pg)
  pg.instance_variable_get(:@condition) rescue nil
end
def get_graphic(pg)
  pg.instance_variable_get(:@graphic) rescue nil
end

# 1. Pictures on disk
pics_disk = Dir["Graphics/Pictures/*"].map{|p| File.basename(p).downcase}
pics_base = pics_disk.map{|f| File.basename(f, ".*").downcase }
puts "=== Pictures on disk: #{pics_disk.size} ==="
puts pics_disk.sort.first(30).join(", ")
puts ""

# Scan ShowPicture refs
refs = Hash.new(0)
ref_locs = Hash.new{|h,k| h[k]=[]}
dir = Dir["Data/Map*.rvdata2"].sort
dir.each do |path|
  begin
    obj = Marshal.load(File.binread(path))
  rescue => e
    next
  end
  events = get_events(obj)
  next unless events
  events.each do |eid, ev|
    next unless ev
    pages = get_pages(ev)
    next unless pages
    pages.each_with_index do |pg, pi|
      list = get_list(pg)
      next unless list
      list.each do |cmd|
        next unless cmd
        code = cmd.instance_variable_get(:@code) rescue cmd.code rescue nil
        next unless code==231
        params = cmd.instance_variable_get(:@parameters) rescue cmd.parameters rescue nil
        next unless params
        name = params[1].to_s
        next if name.nil? || name.empty?
        key = name.downcase
        refs[key]+=1
        ref_locs[key] << "#{File.basename(path)}:ev#{eid}:pg#{pi}"
      end
    end
  end
end
# CommonEvents
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue ce.list rescue nil
    next unless list
    list.each do |cmd|
      code = cmd.instance_variable_get(:@code) rescue nil
      next unless code==231
      params = cmd.instance_variable_get(:@parameters) rescue nil
      next unless params
      name = params[1].to_s
      next if name.nil?||name.empty?
      key=name.downcase
      refs[key]+=1
      ref_locs[key] << "CommonEvents[#{idx}]"
    end
  end
rescue => e
  puts "CE load fail #{e}"
end

puts "=== ShowPicture unique refs: #{refs.size} ==="
sorted = refs.sort_by{|k,v| -v}
sorted.each do |name,cnt|
  base = name.downcase
  exists = pics_base.include?(base)
  status = exists ? "OK" : "MISSING"
  puts "#{status} #{name.inspect.ljust(30)} cnt=#{cnt.to_s.rjust(3)} locs=#{ref_locs[name].first(2).join('; ')}"
end
missing = sorted.select{|name,cnt| !pics_base.include?(name.downcase)}
puts "\nMissing distinct: #{missing.size}"
missing.first(20).each{|n,c| puts " MISSING #{n.inspect} cnt=#{c} loc=#{ref_locs[n].first(3).join(', ')}"}

# 2. Fade/Tint unpaired analysis
puts "\n\n=== Fade/Tint unpaired per event page ==="
unpaired = []
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = get_events(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    pages = get_pages(ev); next unless pages
    pages.each_with_index do |pg, pi|
      list = get_list(pg); next unless list
      codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
      has_fadeout = codes.include?(221)
      has_fadein  = codes.include?(222)
      has_tint_set = codes.include?(223)
      has_flash = codes.include?(224)
      # Report pages that fadeout without fadein AND are not obviously paired via CommonEvent call
      if has_fadeout && !has_fadein
        # Check if list also contains a CommonEvent call (117) that might do fadein
        has_ce_call = codes.include?(117)
        # Still flag but note
        cond = get_cond(pg)
        cond_s = cond ? "#{cond.instance_variable_get(:@self_switch_valid) rescue '?'}:#{cond.instance_variable_get(:@self_switch_ch) rescue '?'}" : "?"
        trig = pg.instance_variable_get(:@trigger) rescue "?"
        name = ev.instance_variable_get(:@name) rescue "?"
        puts "#{File.basename(path)} ev#{eid} '#{name[0,30]}' pg#{pi} trig#{trig} cond_self#{cond_s} has_fadeout_only#{has_ce_call ? ' (+CE call)' : ''} codes=#{codes.join(',')[0,120]}"
        unpaired << [path,eid,pi]
      end
      # Tint that sets to non-zero and never resets in same page? Report all tints
      if has_tint_set
        list.each_with_index do |cmd, ci|
          code = cmd.instance_variable_get(:@code) rescue nil
          next unless code==223
          params = cmd.instance_variable_get(:@parameters) rescue nil
          # params[0] is Tone, params[1] duration, params[2] wait
          tone = params[0] rescue nil
          dur = params[1] rescue "?"
          # Tone has @red @green @blue @gray
          r = tone.instance_variable_get(:@red) rescue "?"
          g = tone.instance_variable_get(:@green) rescue "?"
          b = tone.instance_variable_get(:@blue) rescue "?"
          gr = tone.instance_variable_get(:@gray) rescue "?"
          puts "  TINT #{File.basename(path)} ev#{eid} pg#{pi} [#{ci}] tone=#{r},#{g},#{b},#{gr} dur=#{dur} wait=#{params[2]} "
        end
      end
    end
  end
end
puts "Unpaired fadeout pages: #{unpaired.size}"

# CommonEvents fade analysis
puts "\n=== CommonEvents with Fadeout without matching Fadein ==="
begin
  arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  arr.each_with_index do |ce, idx|
    next unless ce
    list = ce.instance_variable_get(:@list) rescue ce.list rescue nil
    next unless list
    codes = list.map{|c| c.instance_variable_get(:@code) rescue nil}
    next unless codes.include?(221)
    has_in = codes.include?(222)
    name = ce.instance_variable_get(:@name) rescue "?"
    trig = ce.instance_variable_get(:@trigger) rescue "?"
    sw = ce.instance_variable_get(:@switch_id) rescue "?"
    puts "CE#{idx} id=#{ce.instance_variable_get(:@id) rescue '?'} name=#{name.inspect[0,40]} trig=#{trig} sw=#{sw} fadein=#{has_in} codes_count221=#{codes.count(221)} 222=#{codes.count(222)} total=#{codes.size}"
    if !has_in
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code) rescue nil
        if [221,222,223,224,231,235,101,401,102,402,404].include?(code)
          params = cmd.instance_variable_get(:@parameters) rescue nil
          puts " [#{ci}] code=#{code} params=#{params.inspect[0,250]}"
        end
      end
    end
  end
rescue => e
  puts "CE fade err #{e}"
end

# 3. Enemy body detailed
puts "\n\n=== Enemy body events (BattleProcessing on pg0) detailed ==="
cnt_maps=0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events = get_events(obj); next unless events
  found=[]
  events.each do |eid, ev|
    next unless ev
    pages = get_pages(ev); next if pages.nil?||pages.empty?
    pg0 = pages[0]
    list0 = get_list(pg0); next unless list0
    has301 = list0.any?{|c| (c.instance_variable_get(:@code) rescue nil)==301 }
    next unless has301
    found << [eid,ev]
  end
  next if found.empty?
  cnt_maps+=1
  # limit output to first 5 maps with >2 enemies to understand pattern, but print only first 2 events per map to avoid flood
  puts "\n--- #{File.basename(path)} display=#{obj.instance_variable_get(:@display_name).inspect[0,60]} enemies=#{found.size} ---"
  found.first(2).each do |eid, ev|
    name = ev.instance_variable_get(:@name) rescue "?"
    x = ev.instance_variable_get(:@x) rescue "?"
    y = ev.instance_variable_get(:@y) rescue "?"
    pages = get_pages(ev)
    puts "Event #{eid} '#{name}' @#{x},#{y} pages=#{pages.size}"
    pages.each_with_index do |pg, pi|
      trig = pg.instance_variable_get(:@trigger) rescue "?"
      cond = get_cond(pg)
      cond_s = cond ? "self_valid=#{cond.instance_variable_get(:@self_switch_valid) rescue '?'} ch=#{cond.instance_variable_get(:@self_switch_ch).inspect rescue '?'} sw1=#{cond.instance_variable_get(:@switch1_valid) rescue '?'}:#{cond.instance_variable_get(:@switch1_id) rescue '?'}" : "nil"
      gfx = get_graphic(pg)
      gfx_s = gfx ? "tile=#{gfx.instance_variable_get(:@tile_id) rescue '?'} char=#{gfx.instance_variable_get(:@character_name).inspect rescue '?'} idx=#{gfx.instance_variable_get(:@character_index) rescue '?'}" : "nil"
      walk = pg.instance_variable_get(:@walk_anime) rescue "?"
      step = pg.instance_variable_get(:@step_anime) rescue "?"
      dirfix = pg.instance_variable_get(:@direction_fix) rescue "?"
      through = pg.instance_variable_get(:@through) rescue "?"
      list = get_list(pg)
      codes = list.map{|c| c.instance_variable_get(:@code) rescue "?"}.join(",")
      puts " pg#{pi} trig=#{trig} #{cond_s} gfx=[#{gfx_s}] walk=#{walk} step=#{step} dirfix=#{dirfix} through=#{through} codes=#{codes[0,250]}"
      list.each_with_index do |cmd, ci|
        code = cmd.instance_variable_get(:@code) rescue nil
        params = cmd.instance_variable_get(:@parameters) rescue nil
        indent = cmd.instance_variable_get(:@indent) rescue "?"
        next unless [301,601,602,605,205,505,123,122,121,214,132,355,655,108,408,101,401].include?(code)
        puts "  [#{ci}] indent#{indent} code#{code} #{params.inspect[0,480]}"
        if code==205 && params
          mr = params[1]
          if mr
            ml = mr.instance_variable_get(:@list) rescue []
            ml.each do |mc|
              puts "    MR code=#{mc.instance_variable_get(:@code) rescue '?'} params=#{mc.instance_variable_get(:@parameters).inspect[0,100]}"
            end
          end
        end
        if code==108||code==408
          puts "    COMMENT #{params[0].inspect[0,200]}" if params[0].to_s.strip.length>0
        end
      end
    end
  end
  break if cnt_maps>=5
end

puts "\n=== Erase Event and self-switch usage stats across enemy death pages ==="
total_enemy=0
death_page_stats={}
erase_count=0
selfd_count=0
selfa_count=0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  begin; obj=Marshal.load(File.binread(path)); rescue; next; end
  events=get_events(obj); next unless events
  events.each do |eid, ev|
    next unless ev
    pages=get_pages(ev); next if pages.nil?||pages.empty?
    pg0=get_list(pages[0]) rescue nil; next unless pg0
    next unless pg0.any?{|c| (c.instance_variable_get(:@code) rescue nil)==301}
    total_enemy+=1
    # death pages = pages[1..]
    pages[1..-1].each_with_index do |pg, idx|
      pi=idx+1
      trig=pg.instance_variable_get(:@trigger) rescue nil
      cond=get_cond(pg)
      list=get_list(pg); next unless list
      has214 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==214}
      has123 = list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==123}
      erase_count+=1 if has214
      # count self switch D vs A
      list.each do |c|
        next unless (c.instance_variable_get(:@code) rescue nil)==123
        params=c.instance_variable_get(:@parameters) rescue nil
        next unless params
        ch=params[0]
        selfd_count+=1 if ch=="D"
        selfa_count+=1 if ch=="A"
      end
      codes=list.map{|c| c.instance_variable_get(:@code) rescue nil}.join(',')
      key = "trig#{trig}_has214#{has214}_has123#{has123}"
      death_page_stats[key]||=0
      death_page_stats[key]+=1
    end
  end
end
puts "total enemy events=#{total_enemy}"
puts "death page stat keys: #{death_page_stats.inspect}"
puts "erase counts=#{erase_count} self D=#{selfd_count} self A=#{selfa_count}"

# 4. Check map note parallax etc - not needed

# 5. CommonEvents picture CG detailed dump (first few)
puts "\n\n=== CommonEvents picture CG detail (first 3 with ShowPicture) ==="
begin
  arr=Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
  shown=0
  arr.each_with_index do |ce, idx|
    next unless ce
    list=ce.instance_variable_get(:@list) rescue nil; next unless list
    next unless list.any?{|c| (c.instance_variable_get(:@code) rescue nil)==231}
    shown+=1
    name=ce.instance_variable_get(:@name) rescue "?"; trig=ce.instance_variable_get(:@trigger) rescue "?"; sw=ce.instance_variable_get(:@switch_id) rescue "?"
    puts "\nCE#{idx} id=#{ce.instance_variable_get(:@id) rescue '?'} name=#{name.inspect} trig=#{trig} sw=#{sw} total=#{list.size}"
    list.first(60).each_with_index do |cmd, ci|
      code=cmd.instance_variable_get(:@code) rescue nil
      params=cmd.instance_variable_get(:@parameters) rescue nil
      indent=cmd.instance_variable_get(:@indent) rescue "?"
      if [231,232,235,221,222,223,224,201,205,101,401,102,402,404,121,122,123,250,251,236,117,118,119].include?(code)
        puts " [#{ci}] indent#{indent} code#{code} #{params.inspect[0,400]}"
      else
        # show other codes briefly
        puts " [#{ci}] indent#{indent} code#{code} #{params.inspect[0,120]}" if ci<20
      end
    end
    break if shown>=3
  end
rescue => e
  puts "CE pic err #{e} #{e.message} #{e.backtrace[0,3]}"
end
