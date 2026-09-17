# encoding: utf-8
# ============================================================================
# build_joiplay.rb — Builds the JoiPlay (Android) distribution of
#                    Black Souls Arabic (RPG Maker VX Ace).
#
# Why a separate package? JoiPlay's "RPG Maker Plugin" runs VX Ace games with
# an mkxp-based RGSS interpreter. It needs:
#   * Game.rvproj2  -> the VX Ace marker JoiPlay looks for when you add a game
#   * a plain-ASCII Game.ini (the Windows Game.ini here is UTF-16LE for the
#     Arabic title bar and confuses JoiPlay's ini parser)
#   * OGG audio (mkxp cannot decode MP3, so every .mp3 is transcoded to .ogg)
#
# The Windows build stays untouched at the repo root. This script stages a
# sibling folder and zips it.
#
# Usage:  ruby tools/build_joiplay.rb [--check-only]
#   --check-only  run the data audit and exit without building the package.
#
# ffmpeg lookup order:
#   1. ENV["FFMPEG"]
#   2. vendor/ffmpeg/usr/bin/ffmpeg   (project-local, see tools/README)
#   3. ffmpeg on PATH
# ============================================================================
require "fileutils"
require "shellwords"
require "zlib"

VERSION = "1.1.0"
ROOT    = File.expand_path("..", __dir__)
STAGE   = File.join(ROOT, "joiplay", "BLACK_SOULS_ARABIC")
ZIPOUT  = File.join(ROOT, "joiplay", "BLACK_SOULS_ARABIC_joiplay_v#{VERSION}.zip")
CHECK_ONLY = ARGV.include?("--check-only")
STAGE_ONLY = ARGV.include?("--stage-only")
ZIP_ONLY   = ARGV.include?("--zip-only")

# ---------------------------------------------------------------------------
# Marshal stubs (byte-preserving for Table; plain holders for the rest)
# ---------------------------------------------------------------------------
class Table
  def self._load(s); o = allocate; o.instance_variable_set(:@_raw, s); o; end
  def _dump(l); @_raw || ""; end
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
    attr_accessor :events
    class Encounter; end
  end
  class Event
    attr_accessor :id, :name, :pages
    class Page
      attr_accessor :condition, :graphic, :trigger, :list
      class Condition
        attr_accessor :self_switch_valid, :self_switch_ch, :switch1_valid, :switch1_id
      end
      class Graphic
        attr_accessor :character_name
      end
    end
  end
  class MoveRoute; end
  class MoveCommand; end
  class EventCommand
    attr_accessor :code, :indent, :parameters
  end
  class CommonEvent
    attr_accessor :id, :name, :list
  end
  class System; end
  class Troop; end
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

def code(c); c.respond_to?(:code) ? c.code : nil; end
def params(c); c.respond_to?(:parameters) ? (c.parameters || []) : []; end
def load_obj(path); Marshal.load(File.binread(path)); end

# ---------------------------------------------------------------------------
# Audit
# ---------------------------------------------------------------------------
def audit!
  problems = 0
  pics = Dir.glob(File.join(ROOT, "Graphics/Pictures/*")).map { |p| File.basename(p).downcase }

  map_files = Dir.glob(File.join(ROOT, "Data/Map*.rvdata2")).sort.reject { |p| p.end_with?("MapInfos.rvdata2") }
  puts "== Audit: #{map_files.size} maps =="

  enemy_events = 0
  d_erased = 0
  d_empty = 0
  d_other = 0
  fade_leaks = []

  map_files.each do |path|
    obj = load_obj(path) rescue (problems += 1; puts "  FAIL load #{File.basename(path)}: #{$!.class} #{$!.message[0, 80]}"; next)
    events = obj.events || {}
    unless events.keys.all? { |k| k.is_a?(Integer) }
      problems += 1
      puts "  FAIL #{File.basename(path)}: event hash keys are not Integers"
    end
    events.each do |eid, ev|
      next unless ev && ev.pages
      pages = ev.pages
      l0 = (pages[0] && pages[0].list) || []
      is_enemy = l0.any? { |c| code(c) == 301 }
      pages.each_with_index do |pg, pi|
        cond = pg.condition
        if cond && cond.self_switch_valid && cond.self_switch_ch !~ /\A[A-D]\z/
          problems += 1
          puts "  FAIL #{File.basename(path)} ev#{eid} pg#{pi}: invalid self-switch #{cond.self_switch_ch.inspect}"
        end
        list = pg.list || []
        codes = list.map { |c| code(c) }
        # fade balance
        if codes.include?(221) && !codes.include?(222)
          fade_leaks << "#{File.basename(path)} ev#{eid} pg#{pi}"
        end
        # picture refs
        list.each do |c|
          next unless code(c) == 231
          name = params(c)[1].to_s
          next if name.empty?
          next unless name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length < 40
          key = name.downcase
          unless pics.include?(key + ".png") || pics.include?(key + ".jpg") || pics.include?(key)
            problems += 1
            puts "  FAIL #{File.basename(path)} ev#{eid} pg#{pi}: missing picture #{name.inspect}"
          end
        end
        # death pages
        next unless is_enemy && pi > 0 && cond && cond.self_switch_valid && cond.self_switch_ch == "D"
        enemy_events += 1
        gname = (pg.graphic && pg.graphic.character_name.to_s) || ""
        if list.any? { |c| code(c) == 214 }
          d_erased += 1
        elsif gname.empty? && list.all? { |c| [0, nil].include?(code(c)) }
          d_empty += 1
        else
          d_other += 1
          puts "  WARN #{File.basename(path)} ev#{eid} pg#{pi}: D page not erasing (codes=#{list.map { |c| code(c) }.join(',')})"
        end
      end
    end
  end

  # CommonEvents: load + fade balance + picture refs
  ce_path = File.join(ROOT, "Data/CommonEvents.rvdata2")
  ces = load_obj(ce_path) rescue (problems += 1; puts "  FAIL load CommonEvents: #{$!.class}")
  if ces
    ces.each_with_index do |ce, idx|
      next unless ce
      list = ce.list || []
      codes = list.map { |c| code(c) }
      fade_leaks << "CommonEvents[#{idx}] #{ce.name}" if codes.include?(221) && !codes.include?(222)
      list.each do |c|
        next unless code(c) == 231
        name = params(c)[1].to_s
        next if name.empty?
        next unless name =~ /\A[A-Za-z0-9_\-\.]+\z/ && name.length < 40
        key = name.downcase
        unless pics.include?(key + ".png") || pics.include?(key + ".jpg")
          problems += 1
          puts "  FAIL CommonEvents[#{idx}]: missing picture #{name.inspect}"
        end
      end
    end
  end

  # Scripts must still parse + the JoiPlay Win32API guard must be present
  scripts = load_obj(File.join(ROOT, "Data/Scripts.rvdata2")) rescue (problems += 1; puts "  FAIL load Scripts")
  if scripts
    win = scripts.index { |s| s[1].to_s.include?("Window Title") }
    if win
      txt = Zlib::Inflate.inflate(scripts[win][2]).force_encoding("UTF-8")
      unless txt.include?("defined?(Win32API)")
        problems += 1
        puts "  FAIL Scripts: Win32API guard missing in Window Title script"
      end
    end
  end

  puts "  enemy events with D page: #{enemy_events}  (erased: #{d_erased}, empty: #{d_empty}, other: #{d_other})"
  if fade_leaks.empty?
    puts "  fade balance: clean (no FadeOut without FadeIn)"
  else
    puts "  fade balance: #{fade_leaks.size} FadeOut-without-FadeIn (review manually):"
    fade_leaks.first(15).each { |f| puts "    #{f}" }
  end
  puts problems.zero? ? "== Audit PASSED ==" : "== Audit FAILED (#{problems} problems) =="
  exit 1 unless problems.zero?
end

# ---------------------------------------------------------------------------
# ffmpeg discovery
# ---------------------------------------------------------------------------
def find_ffmpeg
  candidates = []
  candidates << ENV["FFMPEG"] if ENV["FFMPEG"]
  candidates << File.join(ROOT, "vendor/ffmpeg/usr/bin/ffmpeg")
  candidates << "/usr/bin/ffmpeg"
  candidates += ENV["PATH"].to_s.split(":").map { |d| File.join(d, "ffmpeg") }
  candidates.find { |c| File.executable?(c) }
end

def ffmpeg_env
  base = File.join(ROOT, "vendor/ffmpeg/usr/lib/x86_64-linux-gnu")
  pulse = File.join(base, "pulseaudio")
  {
    "LD_LIBRARY_PATH" => [base, pulse].select { |d| Dir.exist?(d) }.join(":")
  }
end

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def build!
  puts "\n== Building JoiPlay package =="
  FileUtils.rm_rf(STAGE)
  FileUtils.mkdir_p(File.dirname(ZIPOUT))

  # 1. copy the game folders JoiPlay needs
  FileUtils.mkdir_p(STAGE)
  %w[Data Graphics Audio Fonts Bonus].each do |d|
    src = File.join(ROOT, d)
    FileUtils.cp_r(src, File.join(STAGE, d)) if Dir.exist?(src)
  end
  # drop leftover diagnostic junk from Data (only .rvdata2 belongs in a game)
  Dir.glob(File.join(STAGE, "Data/*")).each do |f|
    FileUtils.rm(f) unless f.end_with?(".rvdata2")
  end
  %w[Map.png LICENSE README.md].each do |f|
    FileUtils.cp(File.join(ROOT, f), STAGE) if File.exist?(File.join(ROOT, f))
  end

  # 2. VX Ace marker file (how JoiPlay detects the game)
  File.write(File.join(STAGE, "Game.rvproj2"), "RPGVXAce 1.02\n")

  # 3. clean plain-text Game.ini for JoiPlay/mkxp (Windows version keeps the
  #    UTF-16LE one at the repo root)
  File.write(File.join(STAGE, "Game.ini"), <<~INI)
    [Game]
    rtp=
    library=
    title=Black Souls AR
  INI

  # 4. MP3 -> OGG (JoiPlay/mkxp cannot play MP3)
  ff = find_ffmpeg
  mp3s = Dir.glob(File.join(STAGE, "Audio/**/*.mp3"))
  unless mp3s.empty?
    if ff.nil?
      warn "!! #{mp3s.size} MP3 files need conversion to OGG for JoiPlay,"
      warn "!! but no ffmpeg was found. Set FFMPEG or install one in vendor/ffmpeg."
      exit 1
    end
    puts "  converting #{mp3s.size} MP3 -> OGG (ffmpeg: #{ff})"
    mp3s.each_with_index do |mp3, i|
      ogg = mp3.sub(/\.mp3\z/, ".ogg")
      cmd = "#{Shellwords.escape(ff)} -y -i #{Shellwords.escape(mp3)} -vn -c:a libvorbis -q:a 5 #{Shellwords.escape(ogg)}"
      ok = system(ffmpeg_env, cmd, out: File::NULL, err: File::NULL)
      unless ok
        warn "  FAILED: #{File.basename(mp3)}"
        exit 1
      end
      FileUtils.rm(mp3)
      puts "  [#{i + 1}/#{mp3s.size}] #{File.basename(ogg)}" if (i + 1) % 10 == 0 || i == mp3s.size - 1
    end
  end

  # 5. install instructions (Arabic + English)
  File.write(File.join(STAGE, "README-JOIPLAY.txt"), <<~TXT)
    النفوس السوداء — نسخة أندرويد (JoiPlay) v#{VERSION}
    ====================================================

    المتطلبات:
      * تطبيق JoiPlay (آخر إصدار)
      * إضافة "RPG Maker Plugin" من داخل JoiPlay (الإضافات)

    طريقة التثبيت:
      1. فك ضغط هذا الملف على هاتفك.
      2. افتح JoiPlay ثم اضغط "+" / "إضافة لعبة".
      3. اختر المجلد BLACK_SOULS_ARABIC (الذي بداخله ملف Game.rvproj2).
      4. ستظهر اللعبة في القائمة — اضغطها للعب.
         (لا حاجة لتنزيل RTP: كل الملفات مضمّنة داخل النسخة.)

    ملاحظات:
      * ملفات الحفظ تُنشأ داخل مجلد اللعبة على ذاكرة الجهاز.
      * التحكم: لوحة مفاتيح افتراضية عبر أيقونة JoiPlay، مع دعم عصا التحكم.
      * موسيقى اللعبة محوّلة إلى OGG لتعمل على JoiPlay.

    ---

    BLACK SOULS — Arabic Edition — Android (JoiPlay) v#{VERSION}

    Requirements: JoiPlay + the "RPG Maker Plugin" (install it from inside JoiPlay).

    Install:
      1. Extract this zip on your phone.
      2. Open JoiPlay, tap "+" / "Add Game".
      3. Select the BLACK_SOULS_ARABIC folder (contains Game.rvproj2).
      4. The game appears in the list — tap to play.
         (No RTP download needed: all assets are bundled.)

    Notes:
      * Save files are stored inside the game folder on the device.
      * Use JoiPlay's virtual keyboard/controller overlay to play.
      * All music was converted to OGG so it plays on JoiPlay.
  TXT

  # 6. zip it (unless --stage-only)
  unless STAGE_ONLY
    puts "  zipping -> #{ZIPOUT}"
    Dir.chdir(File.dirname(STAGE)) do
      ok = system("zip", "-r", "-q", "-1", ZIPOUT, File.basename(STAGE))
      exit 1 unless ok
    end
    size_mb = File.size(ZIPOUT) / 1024.0 / 1024.0
    puts "  done (#{format('%.1f', size_mb)} MB)"
  end
end

audit!
if CHECK_ONLY
  puts "\n(check-only: package not built)"
  exit 0
end
if ZIP_ONLY
  unless Dir.exist?(STAGE)
    warn "staged folder missing: #{STAGE} (run without --zip-only first)"
    exit 1
  end
  puts "== Zipping staged package =="
  Dir.chdir(File.dirname(STAGE)) do
    ok = system("zip", "-r", "-q", "-1", ZIPOUT, File.basename(STAGE))
    exit 1 unless ok
  end
  puts "done (#{format('%.1f', File.size(ZIPOUT) / 1024.0 / 1024.0)} MB)"
  exit 0
end
build!
puts "\nJoiPlay package ready: #{ZIPOUT}" if !STAGE_ONLY
puts "\nStaged (no zip): #{STAGE}" if STAGE_ONLY
