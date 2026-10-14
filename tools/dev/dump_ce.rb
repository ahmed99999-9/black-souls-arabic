#!/usr/bin/env ruby
# repo-root shim (repo cleanup): run this script from any working
# directory; all relative "Data/..." paths resolve to the project root.
Dir.chdir(File.expand_path("../..", __dir__)) unless File.directory?("Data")
# encoding: utf-8
class Table
  def self._load(s)
    o = allocate
    o.instance_variable_set(:@_raw, s)
    o
  end
  def _dump(l)
    @_raw || ""
  end
end
class Color
  def self._load(s)
    allocate
  end
  def _dump(l)
    ""
  end
end
class Tone
  def self._load(s)
    allocate
  end
  def _dump(l)
    ""
  end
end
module RPG
  class Map
    class Encounter
    end
  end
  class Event
    class Page
      class Condition
      end
      class Graphic
      end
    end
  end
  class MoveRoute
  end
  class MoveCommand
  end
  class EventCommand
  end
  class CommonEvent
  end
  class System
  end
  class Troop
    class Page
    end
    class Member
    end
  end
  class Actor
  end
  class Class
  end
  class Skill
  end
  class Item
  end
  class Weapon
  end
  class Armor
  end
  class Enemy
  end
  class State
  end
  class Animation
  end
  class Tileset
  end
  class AudioFile
  end
  class BGM
  end
  class BGS
  end
  class SE
  end
  class ME
  end
  class MapInfo
  end
end

def tone_info(t)
  return "?" unless t
  r = t.instance_variable_get(:@red) rescue nil
  g = t.instance_variable_get(:@green) rescue nil
  b = t.instance_variable_get(:@blue) rescue nil
  gr = t.instance_variable_get(:@gray) rescue nil
  "#{r},#{g},#{b},#{gr}"
end

def dump_ce(arr, idx, label)
  ce = arr[idx]
  return puts("#{label}: nil") unless ce
  id = ce.instance_variable_get(:@id) rescue "?"
  name = (ce.instance_variable_get(:@name) rescue "?").to_s
  name = name.dup.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
  list = ce.instance_variable_get(:@list) rescue []
  puts "\n===== #{label} idx=#{idx} id=#{id} name=#{name.inspect} trigger=#{ce.instance_variable_get(:@trigger) rescue '?'} len=#{list.size} ====="
  list.each_with_index do |cmd, ci|
    code = cmd.instance_variable_get(:@code) rescue "?"
    params = cmd.instance_variable_get(:@parameters) rescue []
    indent = cmd.instance_variable_get(:@indent) rescue 0
    case code
    when 401, 405
      txt = params[0].to_s
      txt = txt.dup.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
      puts "[#{ci}] indent#{indent} #{code}(text) #{txt[0, 90].inspect}"
    when 223
      puts "[#{ci}] indent#{indent} 223 Tint tone=#{tone_info(params[0])} dur=#{params[1]} wait=#{params[2]}"
    when 224
      puts "[#{ci}] indent#{indent} 224 Flash color=#{params[0].inspect} dur=#{params[1]}"
    when 231
      puts "[#{ci}] indent#{indent} 231 ShowPic num=#{params[0]} name=#{params[1].inspect} origin=#{params[2]} x=#{params[3]} y=#{params[4]} zoom=#{params[5]},#{params[6]} op=#{params[7]} blend=#{params[8]}"
    when 232
      puts "[#{ci}] indent#{indent} 232 MovePic num=#{params[0]} d=#{params[1]} #{params[2, 8].inspect}"
    when 235
      puts "[#{ci}] indent#{indent} 235 ErasePic num=#{params[0].inspect}"
    when 221
      puts "[#{ci}] indent#{indent} 221 FadeOut"
    when 222
      puts "[#{ci}] indent#{indent} 222 FadeIn"
    when 230
      puts "[#{ci}] indent#{indent} 230 Wait #{params.inspect}"
    when 117
      puts "[#{ci}] indent#{indent} 117 CallCE #{params.inspect}"
    when 121
      puts "[#{ci}] indent#{indent} 121 ControlSwitch #{params.inspect}"
    when 122
      puts "[#{ci}] indent#{indent} 122 ControlVar #{params.inspect[0, 120]}"
    when 111
      puts "[#{ci}] indent#{indent} 111 CondBranch #{params.inspect[0, 150]}"
    when 411
      puts "[#{ci}] indent#{indent} 411 Else"
    when 412
      puts "[#{ci}] indent#{indent} 412 EndBranch"
    when 101, 102, 402, 404, 108, 408, 355, 655
      puts "[#{ci}] indent#{indent} #{code} #{params.inspect[0, 180]}"
    else
      puts "[#{ci}] indent#{indent} #{code} #{params.inspect[0, 120]}"
    end
  end
end

arr = Marshal.load(File.binread("Data/CommonEvents.rvdata2"))
dump_ce(arr, 201, "CE201")
dump_ce(arr, 74, "CE74")
dump_ce(arr, 75, "CE75")
