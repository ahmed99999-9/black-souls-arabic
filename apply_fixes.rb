# encoding: utf-8
# ============================================================================
# apply_fixes.rb — Black Souls Arabic bug-fix tool (run from project root)
#
# Fixes:
#   1) CommonEvents.rvdata2 — CE201 (التحضير للجولة الجديدة): insert a FadeIn
#      (222) right after the Transfer Player (201) command, so the screen is
#      never left black after the "new round" preparation.
#   2) Map*.rvdata2 — enemy "death" pages (self-switch B/D parallel pages that
#      fade the corpse out and then BACK IN and clear the self-switch, i.e.
#      respawn) are rewritten to fade out, wait briefly, then Erase Event and
#      KEEP the self-switch ON, so killed enemies stay dead.
#   3) Scripts.rvdata2 — script 167 "Window Title Fix": guard all Win32API
#      calls so the game boots on JoiPlay (Android) where user32 does not
#      exist, while keeping the Windows title-bar fix intact.
#
# All files are round-tripped through Marshal with byte-preserving _dump for
# Table/Color/Tone. Run with:  ruby apply_fixes.rb
# ============================================================================
require "zlib"

# ---------------------------------------------------------------------------
# Byte-preserving stubs
# ---------------------------------------------------------------------------
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

def load_obj(path)
  Marshal.load(File.binread(path))
end

def save_obj(path, obj)
  File.binwrite(path, Marshal.dump(obj))
end

def new_cmd(code, indent = 0, params = [])
  c = RPG::EventCommand.new
  c.instance_variable_set(:@code, code)
  c.instance_variable_set(:@indent, indent)
  c.instance_variable_set(:@parameters, params)
  c
end

def new_move_cmd(code, params = [])
  c = RPG::MoveCommand.new
  c.instance_variable_set(:@code, code)
  c.instance_variable_set(:@parameters, params)
  c
end

def cmd_code(cmd)
  cmd.instance_variable_get(:@code) rescue nil
end

def cmd_params(cmd)
  cmd.instance_variable_get(:@parameters) rescue []
end

# ---------------------------------------------------------------------------
# Pass 0 — round-trip verification (no edits)
# ---------------------------------------------------------------------------
puts "=== Pass 0: byte-exact round-trip verification ==="
files = Dir["Data/Map*.rvdata2"].sort + ["Data/CommonEvents.rvdata2", "Data/Scripts.rvdata2"]
rt_fail = 0
files.each do |f|
  obj = load_obj(f)
  tmp = "/tmp/rt_#{File.basename(f)}"
  save_obj(tmp, obj)
  if File.binread(tmp) != File.binread(f)
    rt_fail += 1
    puts "  ROUNDTRIP MISMATCH: #{f}"
  end
end
puts rt_fail.zero? ? "  all #{files.size} files round-trip byte-exact" : "  #{rt_fail} files FAILED round-trip (aborting)"
exit 1 unless rt_fail.zero?

# ---------------------------------------------------------------------------
# Fix 0 — restore Integer keys on @events hashes (localizer tool wrote String
# keys; the engine looks up events by Integer event ids, so move routes,
# Erase Event and event lookups silently failed) and on MapInfos
# ---------------------------------------------------------------------------
puts "\n=== Fix 0: events/MapInfos hash keys -> Integer ==="
key_fixed = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = load_obj(path)
  events = obj.instance_variable_get(:@events) rescue nil
  next unless events && events.is_a?(Hash)
  if events.keys.any? { |k| !k.is_a?(Integer) }
    new_events = {}
    events.each { |k, v| new_events[k.to_i] = v }
    obj.instance_variable_set(:@events, new_events)
    save_obj(path, obj)
    key_fixed += 1
  end
end
mi_path = "Data/MapInfos.rvdata2"
if File.exist?(mi_path)
  infos = load_obj(mi_path)
  if infos.is_a?(Hash) && infos.keys.any? { |k| !k.is_a?(Integer) }
    new_infos = {}
    infos.each { |k, v| new_infos[k.to_i] = v }
    save_obj(mi_path, new_infos)
    puts "  MapInfos keys fixed (#{infos.size} entries)"
  end
end
puts "  maps with event keys fixed: #{key_fixed}"

# ---------------------------------------------------------------------------
# Fix 1 — CE201 FadeIn
# ---------------------------------------------------------------------------
puts "\n=== Fix 1: CE201 FadeIn ==="
arr = load_obj("Data/CommonEvents.rvdata2")
ce = arr[201]
list = ce.instance_variable_get(:@list) rescue []
idx201 = list.index { |c| cmd_code(c) == 201 }
idx222 = list.index { |c| cmd_code(c) == 222 }
if idx222 && idx222 > idx201
  puts "  CE201 already has FadeIn after transfer — skipped"
else
  raise "CE201 transfer (201) not found" unless idx201
  list.insert(idx201 + 1, new_cmd(222, 0, []))
  puts "  inserted FadeIn (222) after command index #{idx201}"
end
save_obj("Data/CommonEvents.rvdata2", arr)

# ---------------------------------------------------------------------------
# Fix 2 — enemy death pages
# ---------------------------------------------------------------------------
puts "\n=== Fix 2: enemy death pages ==="

def page_cond(pg)
  pg.instance_variable_get(:@condition) rescue nil
end
def page_gfx(pg)
  pg.instance_variable_get(:@graphic) rescue nil
end
def page_list(pg)
  pg.instance_variable_get(:@list) rescue []
end

def death_route?(mr)
  return false unless mr
  steps = mr.instance_variable_get(:@list) rescue []
  return false if steps.nil? || steps.empty?
  codes = steps.map { |mc| cmd_code(mc) }
  # pattern: opacity(42) ... wait(15) ... opacity(42) ... end(0)
  codes.include?(42) && codes.include?(15) && codes.last == 0
end

def erase_page!(pg)
  list = page_list(pg)
  # Build: MoveRoute [opacity 0, wait 30] (wait=true), Erase Event, END
  mr = RPG::MoveRoute.new
  mr.instance_variable_set(:@repeat, false)
  mr.instance_variable_set(:@skippable, false)
  mr.instance_variable_set(:@wait, true)
  mr.instance_variable_set(:@list, [
    new_move_cmd(42, [0]),   # change opacity to 0
    new_move_cmd(15, [30]),  # wait 30 frames
    new_move_cmd(0, [])      # end
  ])
  new_list = [new_cmd(205, 0, [0, mr]), new_cmd(214, 0, []), new_cmd(0, 0, [])]
  list.replace(new_list)
end

fixed_d = 0
fixed_b = 0
no_death_page = []
maps_with_enemies = 0
Dir["Data/Map*.rvdata2"].sort.each do |path|
  obj = load_obj(path)
  events = (obj.instance_variable_get(:@events) rescue nil) || {}
  next if events.empty?
  changed = false
  events.each do |eid, ev|
    pages = (ev.instance_variable_get(:@pages) rescue nil) || []
    next if pages.empty?
    l0 = page_list(pages[0])
    next unless l0.any? { |c| cmd_code(c) == 301 }
    maps_with_enemies += 1
    has_d = false
    pages[1..-1].each do |pg|
      cond = page_cond(pg)
      ch = cond.instance_variable_get(:@self_switch_ch) rescue nil
      valid = cond.instance_variable_get(:@self_switch_valid) rescue false
      next unless valid && (ch == "D" || ch == "B")
      trig = pg.instance_variable_get(:@trigger) rescue nil
      gfx = page_gfx(pg)
      gname = (gfx.instance_variable_get(:@character_name) rescue "") || ""
      list = page_list(pg)
      codes = list.map { |c| cmd_code(c) }
      # only rewrite the known death/respawn animation pages
      next unless (trig == 3 || trig == 4)
      next if gname.empty?
      next unless (codes - [0, 205, 505, 123, 108, 408]).empty?
      mr = nil
      list.each do |c|
        next unless cmd_code(c) == 205
        p = cmd_params(c)
        mr = p[1] if p && p.size > 1
      end
      next unless death_route?(mr)
      if ch == "D"
        has_d = true
        erase_page!(pg)
        fixed_d += 1
        changed = true
      end
    end
    no_death_page << "#{File.basename(path)} ev#{eid}" unless has_d
  end
  save_obj(path, obj) if changed
end
puts "  enemy events on #{maps_with_enemies} maps"
puts "  rewrote #{fixed_d} D-pages (B pages left untouched - they are the escape-flicker pages)"
puts "  enemies with no D page at all: #{no_death_page.size}"
puts "    first 15: #{no_death_page.first(15).join(', ')}"

# ---------------------------------------------------------------------------
# Fix 3 — Window Title Fix (Win32API guard for JoiPlay)
# ---------------------------------------------------------------------------
puts "\n=== Fix 3: Window Title Fix Win32API guard ==="
scripts = load_obj("Data/Scripts.rvdata2")
idx167 = scripts.index { |s| s[1].to_s.include?("Window Title") }
raise "script 167 not found" unless idx167
old_code = Zlib::Inflate.inflate(scripts[idx167][2]) rescue scripts[idx167][2]
old_text = old_code.dup.force_encoding("UTF-8").gsub("\r\n", "\n")

patched = old_text.sub(
  /(FindWindow\s*=\s*Win32API\.new\([^\n]+\n\s*SetWindowTextW\s*=\s*Win32API\.new\([^\n]+\)\n)/m,
  "if defined?(Win32API)\n" \
  "  begin\n" \
  "    FindWindow   = Win32API.new('user32', 'FindWindowA', 'PP', 'L')\n" \
  "    SetWindowTextW = Win32API.new('user32', 'SetWindowTextW', 'LP', 'I')\n" \
  "  rescue Exception\n" \
  "    FindWindow   = nil\n" \
  "    SetWindowTextW = nil\n" \
  "  end\n" \
  "else\n" \
  "  FindWindow   = nil\n" \
  "  SetWindowTextW = nil\n" \
  "end\n"
)

# Guard apply_now against nil handles
patched = patched.sub(
  /(def self\.apply_now\n\s*return if @applied\n)/,
  "def self.apply_now\n    return if @applied\n    return unless defined?(FindWindow) && FindWindow\n    return unless defined?(SetWindowTextW) && SetWindowTextW\n"
)

# The call inside apply_now also needs a rescue-wrapped call body already has rescue. Keep.
if patched.include?("defined?(Win32API)")
  scripts[idx167][2] = Zlib::Deflate.deflate(patched.force_encoding("UTF-8"))
  puts "  patched script 167 (#{old_text.bytesize} -> #{patched.bytesize} bytes)"
else
  raise "Window Title Fix patch did not apply"
end
save_obj("Data/Scripts.rvdata2", scripts)

puts "\nDone."
