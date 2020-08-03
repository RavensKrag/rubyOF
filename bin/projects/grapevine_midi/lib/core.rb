
# stores the main logic and data of the program

require 'open3'

# stuff to load just once
require LIB_DIR/'input_handler.rb'
require LIB_DIR/'sequence_memory.rb'
require LIB_DIR/'scheduler.rb'


# stuff to live load ('load' allows for reloading stuff)
load LIB_DIR/'char_mapped_display.rb'
load LIB_DIR/'looper_pedal.rb'

# class definition


# SPIKE_PROFILER_ON = true
# SPIKE_PROFILER_ON = false



# convert time in milliseconds to standard time units (microseconds)
def msec(time)
  (time * 1000).to_i
end

# convert time in microseconds to standard time units (microseconds)
def usec(time)
  (time).to_i
end




class State
  class << self
    def bind_variables(window, display, colors)
      @@window = window
      @@display = display
      @@colors = colors
      
      # 
      # useful unicode characters
      # 
      
      @@hbar = {
        '8/8' => '█',
        '7/8' => '▉',
        '6/8' => '▊',
        '5/8' => '▋',
        '4/8' => '▌',
        '3/8' => '▍',
        '2/8' => '▎',
        '1/8' => '▏',
        '0/8' => ''
      }
      
      @@vbar = {
        '0/8' => '',
        '1/8' => '▁',
        '2/8' => '▂',
        '3/8' => '▃',
        '4/8' => '▄',
        '5/8' => '▅',
        '6/8' => '▆',
        '7/8' => '▇',
        '8/8' => '█'
      }
    end
  end
  
  
  SUBDIVISIONS_PER_BAR = 8
  def horiz_bar_graph(bar_length:, t:, t_max:)
    max_segments = bar_length * SUBDIVISIONS_PER_BAR
    time_per_segment = t_max / max_segments
    
    
    
    num_segments = t / time_per_segment # should be int div
    full_bars = num_segments / SUBDIVISIONS_PER_BAR
    fractions = num_segments % SUBDIVISIONS_PER_BAR
    
    bar_graph  = @@hbar['8/8']*full_bars
    bar_graph ||= '' # bar graph can be nil if full_bars == 0
    bar_graph += @@hbar["#{fractions}/8"]
    
    
    return bar_graph.ljust(bar_length)
  end
end

class BaseState < State
  def initialize
    # clear out the whole buffer
    line = " "*@@display.x_chars
    @@display.y_chars.times do |y|
      @@display.print_string(0,y, line)
    end
    
    # clear out the garbage bg + test pattern fg
    @@display.background.fill_all RubyOF::Color.rgb([(0.0*255).to_i]*3)
    @@display.foreground.fill_all RubyOF::Color.rgb([(1.0*255).to_i]*3)
  end
end

class DebugDisplayClipping < State
  def initialize
    
  end
  
  def update
    @@display.print_string(5, 0, "hello world!")
    # .each do |pos|
      # @@display.background[pos] = RubyOF::Color.rgb( [0, 0, 255] )
    # end
    
    
    @@display.print_string(55, 5, "spatial inputs~")
    @@display.print_string(7, 5, "spatial inputs~")
    # .each do |pos|
      # @@display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
    # end
    
    @@display.print_string(0, 17-3, "bottom clip")
    @@display.print_string(0, 18-3, "this should not print")
    
    
    msg = "gets cut off somewhere in the middle"
    @@display.print_string(30, 9, msg)
    # .each do |pos|
      # @@display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
    # end
    # ^ Enumerator stops at end of display where the text was clipped
    
    
    
    # pos = CP::Vec2.new(10,10)
    # @@display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
    # @@display.foreground[pos] = RubyOF::Color.rgb( [0, 0, 255] )
    
    
    # pos = CP::Vec2.new(50,50)
    # @@display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
    # @@display.foreground[pos] = RubyOF::Color.rgb( [0, 0, 255] )
    # # ^ Attempting to access indicies that are out of range throws exception
  end
  
  def draw
    
  end
end

class DebugAlignDisplayBG < State
  def initialize
    
  end
  
  def update
    # (alternate colored bg lines, dark and light, helps find scaling)
    # (a row of the character "F" helps configure character width)
    c = RubyOF::Color.new.tap do |c|
      c.r, c.g, c.b, c.a = ([(0.0*255).to_i]*3 + [255])
    end
    
    
    
    60.times.each do |i|
      screen_print(font: @fonts[:monospace], 
                   string: "F", color: c,
                   position: @display_origin_px+CP::Vec2.new(i*@char_width_pxs,-10))
    end
    
    
    
    c1 = RubyOF::Color.rgb( [(0.5*255).to_i]*3 )
    c2 = RubyOF::Color.rgb( [(0.7*255).to_i]*3 )
    
    assoc = @display.each_position.group_by{ |pos| pos.y.to_i % 2 }
    
    # assoc[0].each{ |pos| @display.background[pos] = c1 }
    # assoc[1].each{ |pos| @display.background[pos] = c2 }
    
    
    
    # 
    # text display color alignment test
    # 
    
  end
  
  def draw
    
  end
end

class DebugAlignDisplayFG < State
  def initialize
    
  end
  
  def update
    
  end
  
  def draw
    corners = [
      CP::Vec2.new(0,0),
      CP::Vec2.new(1,0),
      CP::Vec2.new(1,1),
      CP::Vec2.new(0,1),
      CP::Vec2.new(@display.x_chars, @display.y_chars),
      CP::Vec2.new(0,                @display.y_chars),
      CP::Vec2.new(@display.x_chars, 0               )
    ]
    
    # @display.each_position
    # .select{ |pos|  pos.x == 0 or pos.x == @display.x_chars-1 }
    # .each do |pos|
      # @display.foreground[pos] = RubyOF::Color.rgb( [255, 0, 0] )
    # end
    
    # @display.each_position
    # .select{ |pos| pos.y == 0 or pos.y == @display.y_chars-1  }
    # .each do |pos|
      # @display.foreground[pos] = RubyOF::Color.rgb( [255, 0, 255] )
    # end
    
    
    
    
    # 
    # line height test pattern 1
    # > same text repeated on many lines + horiz bar graphs of varying length
    # 
    
    # clear background using BB
    
    # CP::BB
    # l,b,r,t
    x = 2
    y = 2
    w = 40
    h = 11
    bb1 = CP::BB.new(x,y, x+w,y+h)
    
    # @display.each_position
    # .select{ |pos|  bb1.contain_vect? pos  }
    # .each do |pos|
    #   @display.background[pos] = RubyOF::Color.hex( 0xb6b198 )
    #   @display.foreground[pos] = RubyOF::Color.hex( 0x32312a )
    # end
    
    ((bb1.b.to_i)..(bb1.t.to_i)).each do |i|
      @display.print_string(CP::Vec2.new(bb1.l, i), " "*(bb1.r-bb1.l+1))
    end
    
    # draw text lines and horizontal bar charts
    10.times do |i|
      @display.print_string(
        CP::Vec2.new(bb1.l+1,bb1.b+i+1),
        "Handglovery 0123456789ABCEFG " + @hbar['8/8']*i+@hbar['3/8']
      )
    end
    
    
    
    # 
    # line height test pattern 2
    # > alternating dark bar / no dark bar across multiple rows
    # 
    
    # clear the background using bb
    
    bb2 = CP::BB.new(50,0, 54,16)
    
    # @display.each_position
    # .select{ |pos| bb2.contain_vect? pos }
    # .each do |pos|
    #   @display.background[pos] = RubyOF::Color.hex( 0xb6b198 )
    #   @display.foreground[pos] = RubyOF::Color.hex( 0x32312a )
    # end
    
    (0..(bb2.t)).each do |i|
      @display.print_string(CP::Vec2.new(bb2.l, i), " "*(bb2.r-bb2.l+1))
    end
    
    # line height test pattern 2
    10.times do |i|
      @display.print_string(
          CP::Vec2.new(50,i*2),
          (@vbar['8/8']*5)
        )
    end
    
  
    
    
    
  end
end

class DebugBarGraphTests < State
  def initialize
    
  end
  
  def update
    # 
    # bar graph tests
    # 
    
    count = 16 # 128 midi notes, so 16 chars of 8 increments each will cover it
    bg_color = RubyOF::Color.rgba( [(0.5*255).to_i]*3 + [255] )
    fg_color = @colors[:lilac]
    
    # @display.print_string(CP::Vec2.new(27,14+0), 'x'*count)
    # .each do |pos|
    #   offset = CP::Vec2.new(0,0)
    #   @display.background[pos+offset] = bg_color
    #   @display.foreground[pos+offset] = fg_color
      
    #   offset = CP::Vec2.new(0,1)
    #   @display.background[pos+offset] = bg_color
    #   @display.foreground[pos+offset] = fg_color
    # end
    
    @display.print_string(
      CP::Vec2.new(27,14+1), @hbar['8/8']*(count-1)+@hbar['1/8']
    )
    
    
    # hmmm drawing a vertical bar is harder, because there's no Enumerators in this direction...
    count = 4
    anchor = CP::Vec2.new(20,15) # bottom left position
    bg_color = RubyOF::Color.rgba( [(0.5*255).to_i]*3 + [255] )
    fg_color = @colors[:pale_yellow]
    
    @display.each_position
    .select{   |pos| pos.x == anchor.x+0  }
    .select{   |pos| ((anchor.y-(count-1))..(anchor.y)).include? pos.y }
    .sort_by{  |pos| -pos.y } # y+ down, so top position has the lowest y value
    .each_with_index do |pos, i|
      @display.print_string(pos + CP::Vec2.new(0,0), 'x')
      
      if i == count-1
        @display.print_string(pos + CP::Vec2.new(1,0), @vbar['3/8'])
      else
        @display.print_string(pos + CP::Vec2.new(1,0), @vbar['8/8'])
      end
      
      
      
      offset = CP::Vec2.new(1,0)
      # @display.background[pos+offset] = bg_color
      # @display.foreground[pos+offset] = fg_color
    end
  end
  
  def draw
    
  end
end

class MidiState < State
  def initialize
    # clear the area where midi message data will be drawn
    
    @anchor = CP::Vec2.new(2,0)
    
    # CP::BB
    # l,b,r,t
    x = @anchor.x
    y = @anchor.y
    w = 50
    h = 11
    @midi_data_bb = CP::BB.new(x,y, x+w,y+h)
    
    @@display.background.fill @midi_data_bb, RubyOF::Color.hex( 0xb6b198 )
    @@display.foreground.fill @midi_data_bb, RubyOF::Color.hex( 0x32312a )
    
    
    ((@midi_data_bb.b.to_i)..(@midi_data_bb.t.to_i)).each do |i|
      @@display.print_string(0,i, " "*(@midi_data_bb.r+1))
    end
    
    
    @first_update = true
  end
  
  def update(midiOut, midiMessageQueue)
    if @first_update
      # scheduler.section name: "test 2a - first draw", budget: msec(16)
      # screen_size = read_screen_size("Screen 0")
      # screen_w, screen_h = screen_size["current"]
      # puts "screen size: #{[screen_w, screen_h].inspect}"
      
      puts "---> callback from ruby"
      midiOut.listOutPorts()
      puts "<--- callback end"
      
      
      @first_update = false
    end
    
    
    # write all messages in buffer to the character display
      
    # TODO: clear an entire zone of characters with "F" because if code crashes (in live load mode) in this section, weird glitches could happen
    # (or just let them happen - it could be pretty!)
    
    # TODO: need a way to shift an existing block of text in the display buffer
    
    
    # 
    # show MIDI note data
    # 
    
    # print header
    bg_color = RubyOF::Color.hex( 0xc4cfff )
    
    @@display.print_string(
      @anchor.x, @anchor.y, "b1 b2 b3  deltatime      pitch      "
    )
    # .each do |pos|
      # @display.foreground[pos] = RubyOF::Color.hex( 0xf6fff6 )
      # @display.foreground[pos] = @colors[:pale_green]
      # @display.foreground[pos] = live_colorpicker
      
      # @display.background[pos] = live_colorpicker
      # @display.background[pos] = bg_color
    # end
    
    x = @anchor.x+0
    y = @anchor.y+0
    w = 50
    h = 1
    bb = CP::BB.new(x,y, x+w,y+h-1)
    @@display.background.fill bb, bg_color
    # @display.foreground.fill bb, RubyOF::Color.hex( 0xf6fff6 )
    
    
    # (color for midi pitch bars)
    x = @anchor.x+20
    y = @anchor.y+1
    w = 15
    h = 9
    bb = CP::BB.new(x,y, x+w,y+h)
      bg_color = RubyOF::Color.rgba( [(0.5*255).to_i]*3 + [255] )
      fg_color = @@colors[:lilac]
    
    @@display.background.fill bb, bg_color
    @@display.foreground.fill bb, fg_color
    
    # dump data on all messages in the queue
    midiMessageQueue.each_with_index do |midi_msg, i|
      
      # midi bytes
      @@display.print_string(@anchor.x+0, @anchor.y+i+1, midi_msg[0].to_s(16))
      @@display.print_string(@anchor.x+3, @anchor.y+i+1, midi_msg[1].to_s(16))
      @@display.print_string(@anchor.x+6, @anchor.y+i+1, midi_msg[2].to_s(16))
      
      
      # deltatime
      midi_dt = midi_msg.deltatime
        max_display_num = 99999.999
      midi_dt = [max_display_num, midi_dt].min
      
      msg = ("%.3f" % midi_dt).rjust(max_display_num.to_s.length)
      @@display.print_string(@anchor.x+10, @anchor.y+i+1, msg)
      
      
      
      # note value (as bar graph)
      count = 16
        # 128 midi notes, so 16 chars of 8 increments each
        # will cover it at 1 fraction per note
      value = 15
      range = 0..127
      bg_color = RubyOF::Color.rgba( [(0.5*255).to_i]*3 + [255] )
      fg_color = @@colors[:lilac]
      
      full_bars = midi_msg.pitch / 8
      fractions = midi_msg.pitch % 8
      
      bar_graph  = @@hbar['8/8']*full_bars
      bar_graph ||= '' # bar graph can be nil if full_bars == 0
      bar_graph += @@hbar["#{fractions}/8"]
      
      @@display.print_string(
        @anchor.x+20, @anchor.y+i+1,
        bar_graph.ljust(count)
      )
      
      
      # ^ it's just this thrashing of colors that kills performance!
      #   Could set these colors once on init, because they're not acutally changing, but I'm curious as to why this operation is just so dang slow
      # (it doesn't seem to be the Enumerator through the single line of the string that's slow - it seems to be the changing of colors)
      
      # setting the colors on the header line is about 35 colorsr
      # setting the colors for every pitch bar is 160 colors total
      # That increase in volume (4.5x) is what takes the latency from negligible to overwhelming. You can see this by simply trying to push the header data 10 times (the exact same data)
        # -> you get the same lag spike
      
      # maybe I can go faster if I completely separate read and write interfaces? right now this ruby Enumerator interface allows for reading, writing, and mutating color data. If those things are all separated out, maybe we can go faster?
      
      # How does the PNG library I was using in that one gamejam work? That library seemed pretty fast (even though I never benchmarked it.) Can I copy something from that code and go super fast?
      # (oops, it was a bmp library. well... whatever)
      
      
      
      # signal name
      # (on, off, CC, etc)
      status_string =
        case midi_msg.status
        when :note_on
          "on"
        when :note_off
          "off"
        when :control_change
          "CC" # <-- no pitch or velocity data, control and value instead
        else
          "???"
        end
      status_string = status_string.ljust(3)
        # ^ justify to max length of any one string 
        #   so that you don't get ghosting of old characters
      
      midi_msg.status
      @@display.print_string(
        @anchor.x+38, @anchor.y+i+1,
        status_string
      )
      
      
      # channel
      @@display.print_string(
        @anchor.x+44, @anchor.y+i+1,
        "ch#{midi_msg.channel.to_s.ljust(2)}"
        # ^ there are 16 possible midi channels
        #   thus, worse case the channel name has 2 digits in it
      )
      
    end
    
  end
  
  def draw
    
  end
end

class ProfilerState < State
  def initialize(update_scheduler, draw_durations)
    @update_scheduler = update_scheduler
    @draw_durations = draw_durations
    
    @anchor = CP::Vec2.new(2,17)
    
    
    bg_color = RubyOF::Color.rgb( [(0.2*255).to_i]*3 )
    fg_color = RubyOF::Color.rgb( [(0.7*255).to_i]*3 )
    
    x = @anchor.x
    y = @anchor.y
    w = 56
    h = 11
    bb = CP::BB.new(x,y, x+w-1,y+h-1)
    
    
    
    @@display.background.fill bb, bg_color
    @@display.foreground.fill bb, fg_color
    
    blank_line = " "*w
    h.times do |i|
      @@display.print_string(@anchor.x, i, blank_line)
    end
    
    
    
    
    x = 35
    y = 18
    w = 20
    h = 10
    bar_graph_bb = CP::BB.new(x,y, x+w-1,y+h-1)
    
    bar_bg_color = RubyOF::Color.rgb( [(0.4*255).to_i]*3 )
    bar_fg_color = @@colors[:lilac]
    
    @@display.background.fill bar_graph_bb, bar_bg_color
    @@display.foreground.fill bar_graph_bb, bar_fg_color
  end
  
  def update(whole_iter_dt)
  # RubyOF::CPP_Callbacks.SpikeProfiler_begin("section: profilr")
  # RB_SPIKE_PROFILER.enable
  # run_profiler do
  
    # 
    # display timing data
    # 
    # puts @update_scheduler.time_log.size
    
    
    # @statistics ||= Hash.new
    @statistics ||= Array.new
    
    
    
    
    # 
    # update statistics based on latest data
    # 
    
    @update_scheduler.performance_log&.compact&.tap do |log|
      n = @update_scheduler.sample_count
      
      # puts "log size: #{log.size}"
      
      log.each_with_index do |data, i|
        section_name, time_budget, dt = data
        # update min, max, and average for each section
        
        if @statistics[i].nil?
          min = dt
          max = dt
          avg = dt
        else
          min, max, avg = @statistics[i]
          
          min = [min, dt].min
          max = [max, dt].max
          avg = (dt + avg*n) / (n+1)
        end
        @statistics[i] = [min, max, avg]
        
      end
      
      # p @statistics
      
      # plot data to the character display
      # 
      
      x_offsets = [1, 17]
      
      # titles
      i = 0
      [nil, '--avg--']
      .zip(x_offsets) do |title, x_offset|
        next if title.nil?
        
        @@display.print_string(@anchor.x+x_offset-1, @anchor.y+i, title)
      end
      
      
      # data rows
        # @statistics.each_with_index do |i, data|
        # min, max, avg = data.map{ |x| x.to_s.rjust(6) }
      @statistics.each_with_index do |data, i|
        
        min, max, avg = data.map{ |x| x.to_s.rjust(6) }
        sec_name, time_budget, dt = @update_scheduler.performance_log[i]
        
        
        @@display.print_string(@anchor.x+x_offsets[0], @anchor.y+i+1, sec_name)
        @@display.print_string(@anchor.x+x_offsets[1], @anchor.y+i+1, avg)
        
        
        # bar_graph = 
        #   horiz_bar_graph(t: time_budget, t_max: msec(16),
        #                   bar_length: 20)
        
        # @@display.print_string(@anchor.x+33, @anchor.y+i+1, bar_graph)
        
      end
      
      # sum of all sections (sum of min, sum of max, sum of average, etc)
      i = -1
      
      sum_min, sum_max, sum_avg = 
        @statistics.transpose
        .collect{ |vals| vals.reduce(&:+) }  # sum up each column
        .collect{ |x|    x.to_s.rjust(6)  }  # convert numbers to strings
      
      @@display.print_string(@anchor.x+x_offsets[1], @anchor.y+i, sum_avg)
      
      
      
      if @max_whole_iter_dt.nil?
        @whole_iter_counter = 1
        @max_whole_iter_dt = whole_iter_dt
      else
        dt  = @max_whole_iter_dt
        n   = @whole_iter_counter
        avg = @max_whole_iter_dt
        
        avg = (dt + avg*n) / (n+1)
        
        @max_whole_iter_dt = avg
      end
      dt = @max_whole_iter_dt.to_s
      
      @@display.print_string(@anchor.x+30, @anchor.y+i, dt)
      
      @whole_iter_counter += 1
      
      
      # compare with timings for entire #draw and #update phases, as well as combined #draw + #update
        # (measure each callback, rather than summing)
        # (ideally, the values would be the same as summing, but at the very least there is some overhead we are not measuring)
      
      
      # TODO: time entire #draw phase
      # TODO: time entire #update phase
      # TODO: separate logging of time into a separate class (* not Scheduler) to make it easier to measure both #update and #draw
      
      
      
      
      
      # i = 10
      # puts i # i >= 10
        
        
        # @@display.print_string(@anchor.x+ 1, @anchor.y+i,  'draw')
        
        # @@display.print_string(@anchor.x+10, @anchor.y+i,  min.to_s.rjust(6))
        # @@display.print_string(@anchor.x+17, @anchor.y+i,  avg.to_s.rjust(6))
        # @@display.print_string(@anchor.x+25, @anchor.y+i,  max.to_s.rjust(6))
      
      
        # @@display.print_string(
        #   @anchor.x+33, @anchor.y+i,
        #   horiz_bar_graph(t: msec(1.5), t_max: msec(16),
        #                  bar_length: 20)
        # )
      
    end
    
    
    # 
  # end
  # RB_SPIKE_PROFILER.disable
  # RubyOF::CPP_Callbacks.SpikeProfiler_end()
  end
end

class ColorPickerState < State
  def initialize
    @anchor = CP::Vec2.new(63,9)
    @bg_color = RubyOF::Color.rgb( [0, 0, 0] )
    @fg_color = RubyOF::Color.rgb( [(0.5*255).to_i]*3 )
  end
  
  def update(color_picker)
    pos = @anchor + CP::Vec2.new(0,0)
    @@display.print_string(pos.x, pos.y, "r  g  b  a ")
    
    color_picker.color.tap do |c|
      output_string = c.to_a.map{|x| x.to_s(16).rjust(2, '0') }.join(",")
      
      pos = @anchor + CP::Vec2.new(0,1)
      @@display.print_string(pos.x, pos.y, output_string)
      
      x = @anchor.x-2
      y = @anchor.y+1
      w = 15
      h = 1
      bb = CP::BB.new(x,y, x+w-1,y+h-1)
      @@display.background.fill bb, c
      @@display.foreground.fill bb, RubyOF::Color.rgb( [(0.5*255).to_i]*3 )
    end
  end
end

class MousePositionState < State
  def initialize(mouse)
    @mouse = mouse
    
    @bb = CP::BB.new(40,12, 58,14)
    @anchor = CP::Vec2.new(@bb.l, @bb.b)
  end
  
  def update
  # run_profiler do
  
    @@display.background.fill @bb, RubyOF::Color.hex( 0xb6b198 )
    @@display.foreground.fill @bb, RubyOF::Color.hex( 0x32312a )
    
    
    ((@bb.b.to_i)..(@bb.t.to_i)).each do |y|
      @@display.print_string(@bb.l, y, " "*(@bb.r-@bb.l+1))
    end
    
    
    pos = @anchor+CP::Vec2.new(1,1)
    @@display.print_string(pos.x, pos.y, "mouse @ ")
    
    pos = @anchor+CP::Vec2.new(9,1)
    @@display.print_string(pos.x, pos.y,
      "[" + @mouse.to_a.map{|x| x.to_i.to_s.rjust(2) }.join(', ') + "]"
    )
    # ^ @mouse coordinates are stored as float, but displayd as int
    #  (this enables easy out-of-bounds detection)
    #  (as it removes rounding error for numbers between 0 and -1)
    
    
    if(@mouse.x < 0 || @mouse.x >= @@display.x_chars ||
       @mouse.y < 0 || @mouse.y >= @@display.y_chars
    )
      pos = @anchor+CP::Vec2.new(3,2)
      @@display.print_string(pos.x, pos.y,
        "out-of-bounds"
      )
    end

  # end
  end
end


class Core
  def initialize(window)
    @w = window
  end
  
  def setup
    ofBackground(200, 200, 200, 255)
    ofEnableBlendMode(:alpha)
    
    @update_scheduler = Scheduler.new(self, :on_update, msec(16-4))
    @draw_durations = Array.new # stores profiler data for #draw
    
    
    @first_update = true
    @mouse = CP::Vec2.new(0,0)
    
    
    @midi_msg_memory = SequenceMemory.new
    @input_handler = InputHandler.new
    
    
    
    @fonts = Hash.new
    
    @fonts[:english] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        # TakaoPGothic
        x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
        x.size = 23
        x.add_alphabet :Latin
      end
     
    # @fonts[:japanese] = 
    #     RubyOF::TrueTypeFont.dsl_load do |x|
    #       # TakaoPGothic
    #       # ^ not installed on Ubunut any more, idk why
    #       # try the package "fonts-takao" or "ttf-takao" as mentioned here:
    #       # https://launchpad.net/takao-fonts
    #       x.path = "Noto Sans CJK JP Regular" # comes with Ubuntu
    #       x.size = 40
    #       x.add_alphabet :Latin
    #       x.add_alphabet :Japanese
    #     end
    
    
    @fonts[:monospace] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        x.path = "DejaVu Sans Mono"
        x.size = 24
        #  6 is ok = 9.3125    5/16
        #  9 is ok = 13.96875  33/64
        # 12 is ok = 18.625    5/8
        # 15 is ok = 23.28125  1/64
        # 18 is ok = 27.9375   7/16
        # 24 is ok = 37.25     1/4
        # 33 is ok = 51.21875  7/32
        # 36 is ok = 55.875    7/8
        # 42 is ok = 65.1875   3/16
        # 45 is ok = 69.84375  33/64
        # 48 is ok = 74.5               24*2
        # 96 is ok = 149.0 (EXACTLY)    24*4
        
        
        x.add_alphabet :Latin
        x.add_unicode_range :BlockElement
      end
    
    
    
    @colors = {
      :lilac       => RubyOF::Color.hex_alpha( 0xf6bfff, 0xff ),
      :pale_blue   => RubyOF::Color.hex_alpha( 0xa2f5ff, 0xff ),
      :pale_green  => RubyOF::Color.hex_alpha( 0x93ffbb, 0xff ),
      :pale_yellow => RubyOF::Color.hex_alpha( 0xfffcac, 0xff ),
    }
    
    
    
    
    
    
    
    
    
    # 
    # text display alignment variables
    # 
    
    descender_height = @fonts[:monospace].descender_height.floor
    @line_height = 39
    @char_width_pxs = 19
    @bg_offset = CP::Vec2.new(0,-@line_height-descender_height)
    @bg_scale  = CP::Vec2.new(@char_width_pxs,@line_height)
    
    
    # 
    # configure monospace font used in text display (and elsewhere)
    # 
    
    @fonts[:monospace].tap do |f|
      f.line_height = @line_height
      # f.line_height = f.ascender_height - f.descender_height
      # f.line_height = f.ascender_height.ceil - f.descender_height.floor
      # f.line_height = (f.ascender_height - f.descender_height).ceil
      # f.line_height = (f.ascender_height - f.descender_height).floor
    end
    
    
    
    
    
    # NOTE: @display uses a special version of font that it keeps track of, rather than the monospace font object declared above. do I still need the code above? (maybe for sprites / other floating text?)
    
    
    @display_origin_px = CP::Vec2.new(340,50)
    
    @display =
      RubyOF::Project::CharMappedDisplay.new.tap do |d|
        font_settings =
          RubyOF::TrueTypeFontSettings.new("DejaVu Sans Mono", 24)
          .tap do |settings|
            settings.add_alphabet :Latin
            settings.add_unicode_range :BlockElement
          end
        
        d.setup_font(font_settings)
        d.font.line_height = @line_height
        
        
        w,h = [78, 29]
        d.setup(w,h, @display_origin_px, @bg_offset, @bg_scale)
        
        d.remesh()
        
      end
    
    
    
    
    
    State.bind_variables(@w, @display, @colors)
    
    @main_modes = Array.new
    @main_modes[0] = BaseState.new
    
    
    @debugging = true
    @debug_mode = nil
    
    
    
    # run the "normal" stuff only when all of the debug modes are disabled
    
    
    
    
    # [
    #   ['x', 2, 72,     64, 0],
    #   ['d', 2, 72+7,   64, 0],
    #   ['h', 3, 72+2+7, 64, 0],
    #   ['c', 3, 72+3+7, 64, 0],
    #   ['n', 3, 72+7,   64, 0]
    # ].each do |char, channel, note, on_velocity, off_velocity|
    #   btn_id = char.codepoints.first
      
    #   @input_handler.register_callback(btn_id) do |btn|
    #     btn.on_press do
    #       puts "press #{char}"
          
    #       @w.cpp_ptr["midiOut"].sendNoteOn(channel, note, on_velocity)
    #     end
        
    #     btn.on_release do
    #       puts "release #{char}"
          
    #       @w.cpp_ptr["midiOut"].sendNoteOff(channel, note, off_velocity)
    #     end
        
    #     btn.while_idle do
          
    #     end
        
    #     btn.while_active do
          
    #     end
    #   end
    # end
    
    
    
    
    
    @update_steps = 0
    @draw_steps = 0 
    
    
    # number of steps will vary depending on what debug modes (if any) are set
    # let's count the number in the standard mode for now (no debug flags)
    
    # update     5 (5 calls to yield)
    # draw       4 (4 calls to yield)
    # ^ this explains the behavior I saw - the two loops are not in sync
    
    # if the entire loop is stepped, there is no flicker
    # (not even in the GUI)
    # but the elements of ofxGUI (drawn at C++ level only)
    # will flicker if it takes more than one C++ cycle to complete rendering
    # => program will flicker a little, but will remain responsive on "lag"
    
    
    # OF_KEY_LEFT
    # OF_KEY_RIGHT
    @input_handler.register_callback(OF_KEY_RIGHT) do |btn|
      btn.on_press do
        @update_steps = 5
        @draw_steps   = 4
      end
      
      btn.on_release do
        
      end
      
      btn.while_idle do
        
      end
      
      btn.while_active do
        
      end
    end
    
    
    
    
    
    @looper_pedal = LooperPedal.new
    
    btn_id = 'x'.codepoints.first
    @input_handler.register_callback(btn_id, &@looper_pedal.button_handler)
    
    
    
    
    
    
    
    @fonts[:monospace].tap do |f|
      puts "font line height: #{f.line_height}"
      puts "font  ascender height: #{f.ascender_height}"
      puts "font descender height: #{f.descender_height}"
      p @display.instance_variable_get(:@em_width)
      puts "computed line height: #{f.ascender_height - f.descender_height }"
      puts "computed em height: #{f.string_bb('m', 0,0, true).height }"
      puts "computed ex height: #{f.string_bb('x', 0,0, true).height }"
      puts "computed caps height?: #{f.string_bb('T', 0,0, true).height }"
    end
    
    
    
    
    @display.flushColors_bg
    @display.flushColors_fg
    
    # GC.disable
  end
  
  
  def on_reload
    @shader_files = nil
    @shaderIsCorrect = nil
    setup()
    @looper_pedal.setup
  end
  
  
  # use a structure where Fiber does not need to be regenerated on reload
  def update
    # puts ">>>>>>>> update #{RubyOF::Utils.ofGetElapsedTimeMicros}"
    @start_time = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # puts "update thread: #{Thread.current.object_id}" 
    
    # if SPIKE_PROFILER_ON
    #   RB_SPIKE_PROFILER.enable
    # end
    
    # puts "--> start update"
    signal = @update_scheduler.resume
    # puts signal
    # puts "<-- end update"
    
    # if SPIKE_PROFILER_ON
    #   RB_SPIKE_PROFILER.disable
    #   puts "\n"*7
    # end
  end
  
  # methods #update and #draw are called by the C++ render loop
  # Their only job now at the Ruby level is to set up Fibers
  # which call the true render logic. This structure is necessary
  # to allow for live loading - if the update / draw logic
  # is directly inside the Fiber, there's no good way to reload it
  # when the file reloads.
  def on_update(scheduler)
    scheduler.section name: "shaders", budget: msec(1.5)
      puts "shaders" if Scheduler::DEBUG
      
      # liveGLSL.foo "char_display" do |path_to_shader|
        # @display.reload_shader
      # end
      
      
      # prototype possible smarter live-loading system for GLSL shaders
      
      
      bg_shader_name = "char_display_bg"
      fg_shader_name = "char_display"
      
      @shader_files ||= [
        PROJECT_DIR/"bin/data/#{bg_shader_name}.vert",
        PROJECT_DIR/"bin/data/#{bg_shader_name}.frag",
        PROJECT_DIR/"bin/data/#{fg_shader_name}.vert",
        PROJECT_DIR/"bin/data/#{fg_shader_name}.frag"
      ]
      
      @shaderIsCorrect ||= nil # NOTE: value manually reset in #on_reload
      
      # load shader if it has never been loaded before, or if the files have been updated
      if @shaderIsCorrect.nil? || @shader_files.any?{|f| @shader_timestamp.nil? or f.mtime > @shader_timestamp }
        loaded = @display.load_shaders(bg_shader_name, fg_shader_name)
        
        
        
        puts "load code: #{loaded}"
        # ^ apparently the boolean is still true when the shader is loaded with an error???
        
        puts "loaded? : #{@display.fg_shader_loaded?}"
        # ^ this doesn't work either
        
        # puts "loaded? : #{@display.bg_shader_loaded?}"
        
        
        
        # This is a long-standing issue, open since 2015:
        
        # https://forum.openframeworks.cc/t/identifying-when-ofshader-hasnt-linked/30626
        # https://github.com/openframeworks/openFrameworks/pull/3734
        
        # (the Ruby code I have here is still better than the naieve code, because it prevents errors from flooding the terminal, but it would be great to detect if the shader is actually correct or not)
        
        
        if loaded
          case @shaderIsCorrect
          when true
            # good -> good
            puts "GLSL: still good"
          when false
            # bad -> good
            puts "GLSL: fixed!"
          when nil
            # nothing -> good
            puts "GLSL: shader loaded"
          end
          
          @shaderIsCorrect = true
        else
          case @shaderIsCorrect
          when true
            # good -> bad
            puts "GLSL: something broke"
          when false
            # bad -> bad
            puts "GLSL: still broken..."
          when nil
            # nothing -> bad
            puts "GLSL: could not load shader"
          end
          
          @shaderIsCorrect = false;
        end
          
        
        @shader_timestamp = Time.now
      end
    
    
    if @debugging
      
      # scheduler.section name: "debug setup", budget: msec(0.5)
      # @debug_mode ||= DebugDisplayClipping.new
      
      # scheduler.section name: "debug run", budget: msec(1.0)
      
      # @debug_mode.update
      
      
      scheduler.section name: "profiler init", budget: msec(1)
      puts "profiler" if Scheduler::DEBUG
      
      @main_modes[1] ||= ProfilerState.new(@update_scheduler, @draw_durations)
      
      
      scheduler.section name: "profiler run", budget: msec(4)
      
      @main_modes[1].update(@whole_iter_dt)
      
    end
    
    # # scheduler.section name: "test 2", budget: msec(0.2)
    #   puts "test 2" if Scheduler::DEBUG
    #   @input_handler.update
      
      
    
    # # scheduler.section name: "test 3", budget: msec(2.5)
    #   puts "test 3" if Scheduler::DEBUG
      
    #   # p @w.cpp_val["midiMessageQueue"]
      
    #   delta = @midi_msg_memory.delta_from_sample(@w.cpp_val["midiMessageQueue"])
    #   # print "diff size: #{diff.size}  "; p diff.map{|x| x.to_s }
    
    #   delta.each do |midi_msg|
    #     # case midi_msg[0]
    #     # when 0x90 # note on
    #     #   @w.cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+4, midi_msg.velocity)
    #     #   @w.cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+7, midi_msg.velocity)
    #     #   # puts "ON: #{midi_msg.to_s}"
          
    #     # when 0x80 # note off
    #     #   @w.cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+4, midi_msg.velocity)
    #     #   @w.cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+7, midi_msg.velocity)
    #     #   # puts "OFF: #{midi_msg.to_s}"
          
    #     # end
        
    #   end
      
    
    
    # # scheduler.section name: "test 4", budget: msec(0.2)
    #   puts "test 4" if Scheduler::DEBUG
      
    #   @looper_pedal.update(delta, @w.cpp_ptr["midiOut"])
      
      
      
    #   live_colorpicker = @w.cpp_ptr["colorPicker_color"]
    
    
    
    scheduler.section name: "color", budget: msec(1)
      puts "color" if Scheduler::DEBUG
      # 
      # color picker data
      # 
      
      @main_modes[10] ||= ColorPickerState.new
      @main_modes[10].update(@w.cpp_ptr["color_picker"])
    
    
    scheduler.section name: "mouse", budget: msec(1)
      puts "mouse" if Scheduler::DEBUG
      # 
      # mouse data
      # 
      
      @main_modes[11] ||= MousePositionState.new(@mouse)
      @main_modes[11].update
    
    
    
    scheduler.section name: "midi", budget: msec(8)
      # @main_modes[12] ||= MidiState.new
      
      # @main_modes[12].update(@w.cpp_ptr["midiOut"],
      #                        @w.cpp_val["midiMessageQueue"])
      
      bb_0 = CP::BB.new(2,0, 58,11)
      bg_color = RubyOF::Color.hex( 0x2D2A2E )
      @display.background.fill bb_0, bg_color
      @display.foreground.fill bb_0, RubyOF::Color.hex( 0xFCFCFC )
      
      w = bb_0.r - bb_0.l + 1
      h = bb_0.t - bb_0.b + 1
      
      x = bb_0.l
      y = bb_0.b
      @display.print_string(x,y, "#{[w,h].inspect}")
      
      # default background of dots
      y += 1
      @display.print_string(x,y+0, "."*w) # leading top empty line
      @display.print_string(x,y+1, "."*w)
      @display.print_string(x,y+2, "."*w)
      @display.print_string(x,y+3, "."*w)
      @display.print_string(x,y+4, "."*w)
      @display.print_string(x,y+5, "."*w)
      @display.print_string(x,y+6, "."*w)
      @display.print_string(x,y+7, "."*w)
      @display.print_string(x,y+8, "."*w)
      @display.print_string(x,y+9, "."*w)
      @display.print_string(x,y+10, "."*w) # trailing bottom empty line
      
      # headers
      @display.print_string(x+ 6,y+1, 00.to_s.rjust(3, '0'))
      @display.print_string(x+16,y+1, 10.to_s.rjust(3, '0'))
      @display.print_string(x+26,y+1, 20.to_s.rjust(3, '0'))
      @display.print_string(x+36,y+1, 30.to_s.rjust(3, '0'))
      @display.print_string(x+6,y+2, "0123456789"*4)
      
      # alternating bg colors to distingush blocks
      bb_1 = CP::BB.new(8,4, 17,10)
      # @w.cpp_ptr["color_picker"].color = bg_color
      # @display.background.fill bb_1, @w.cpp_ptr["color_picker"].color
      @display.background.fill bb_1, RubyOF::Color.hex( 0x474248 )
      shift = 20
      bb_2 = CP::BB.new(bb_1.l+shift,bb_1.b, bb_1.r+shift,bb_1.t)
      @display.background.fill bb_2, RubyOF::Color.hex( 0x474248 )
      
      # left side labels for each line
      @display.print_string(x+0,y+3, "In  x|".gsub('x', 4.to_s))
      @display.print_string(x+0,y+4, "In  x|".gsub('x', 3.to_s))
      @display.print_string(x+0,y+5, "In  x|".gsub('x', 2.to_s))
      @display.print_string(x+0,y+6, "In  x|".gsub('x', 1.to_s))
      @display.print_string(x+0,y+7, "Shift|")
      @display.print_string(x+0,y+8, "Out x|".gsub('x', 1.to_s))
      @display.print_string(x+0,y+9, " usr |")
      
      
      # TODO: synth should send each string's notes on a separate channel so you don't have to assume what notes are on what string
      
      # TODO: shrink character size so I can fit more time on the screen at once
      
      # TODO: make sure shader variables for character grid display can be adjusted as the font size used with the grid changes (either pass to GPU or bake into shader code with ruby's file / string manipulation)
      
            
      # 
      # use SequenceMemory class to get diffs from current midi buffer,
      # and use diffs to construct full history of midi events,
      # timestamped using absolute timepoints
      # 
      @midi_history ||= Array.new
      @midi_time ||= 0
      
      midi_queue = @w.cpp_val["midiMessageQueue"]
      @midi_msg_memory.delta_from_sample(midi_queue)&.each do |midi|
        # puts "time: #{midi.deltatime}"
          # when RubyOF starts up, first deltatime == 0
        
        # convert to absolute time
        # NOTE: must add *before* saving time to buffer, otherwise errors / lag
        @midi_time += midi.deltatime # float, ms
        
        # reset buffer if over time threshold
        if (@midi_time)/16.66 > 40 # ms to frames
          @midi_history.clear
          @midi_time = 0
        end
        
        # save absolute time data to buffer
        @midi_history << [ @midi_time, midi ]
      end
      
      # visualize absolute time data on timeline
      @midi_history.each do |abs_time, midi|
        # puts "#{midi.to_s} @ #{(abs_time/16.66).to_i}"
        # puts @midi_history.size
        
        time = (abs_time/(16.66)).to_i  # timestamp -> frame
        row  = 4-((midi.pitch-56)/7)    # row / channel (1..4)
        btn  =   ((midi.pitch-56)%7+1)  # button_i (1..8)
        
        @display.print_string(x+6+time,y+3+row-1, btn.to_s)
      end
      
      
      
      # TODO: reset history if time between events is too long
      # (useful for current debugging stage)
      # (can start over from beginning of line)
      
      
      
      
      # puts midi.pitch
      
      
    
    
    
    scheduler.section name: "color", budget: msec(1.0)
      
      # @w.cpp_ptr["color_picker"].color = RubyOF::Color.hex( 0xb6b198 )
      # ^ this code works now, but can't call it every frame, otherwise I will never be able to actually use the color picker UI
      
      # TODO: call in more appropriate manner
      # TODO: consider changing interface to ruby-style 'color=' naming
    
    
    scheduler.section name: "cleanup", budget: msec(1.0)
    
      # @display.flushColors_bg()
      # @display.flushColors_fg()
      @display.flush
      
      @display.remesh()
      
    # --- end of "cleanup 2" ---
    
    
    
    
    
    # TODO: consider switching statistics: use lowest of all time, highest of all time, and average over all time points (use moving average)
    
    # TODO: draw min / max / avg as sprites on top of the bars (visualize)
    
    # TODO: update time budget on 5a and 5c
      # (I saw large spikes for both of these. What's going on? Can we optimize these routines at all?)
    
    # TODO: establish stronger upper bound time budget of cleanup2
    
      # TODO: clean up old profiler data files
      # (lots of temp files cluttering up my sublime text session right now...)
      
      # TODO: write up what I learned in a paper and close some browser tabs
    
    # TODO: update time budget on 'profilr' section
    
    # TODO: add graph showing how many frames it takes to complete a full cycle
    
    # TODO: make sure you can align things in time s.t. a full cycle happens in a predictable integral number of frames - don't want scheduler to just pack everything in there at the cost of understanding timings.
    
      # But it would be great if the system could still tolerate spikes that are way over budget? That would be great for sketching early code ideas.
      
      # Maybe I just want the ability to pad things out?
    
    
    
    
    
    scheduler.section name: "end", budget: msec(0.1)
    # ^ this section does literally nothing,
    #   but if I set the budget to 1000 us, it can take as much as 925 us
    #   with budget at 100 us, it seems to cap at 162 um
    #   thus, it appears that the max time used depends on the budget given
    #   why is that?
    #   what about the scheduling algorithm produces this behavior?
    # 
    # nope, just saw a max of 826 us with a budget of 0.1 us
    # (not sure when I saved - have to try this again...)
    # 
    # currently seeing max of 697 us with a budget of 100 us
    # I think that the time consumed can go over budget, even when total budget < 16.6 ms - which is what I expected the code to do
    
    # puts "end"
    
    

    
  end
  
  
  
  
  
  def draw
    # puts ">>>>>>>> draw #{RubyOF::Utils.ofGetElapsedTimeMicros}"
    
    # puts "draw thread:   #{Thread.current.object_id}" 
    
    # draw_start = Time.now
    draw_start = RubyOF::Utils.ofGetElapsedTimeMicros
    
      on_draw()
    
    # draw_end = Time.now
    draw_end = RubyOF::Utils.ofGetElapsedTimeMicros
    dt = draw_end - draw_start
    puts "draw duration: #{dt}" if Scheduler::DEBUG
    
    
    
    draw_duration_history_len = 100
    
    
    @draw_durations << dt
    # puts "draw duration: #{dt}"
    
    if @draw_durations.length > draw_duration_history_len
      d_len = @draw_durations.length - draw_duration_history_len
      @draw_durations.shift(d_len)
    end
    
    
    
    
    if @start_time
      end_time = RubyOF::Utils.ofGetElapsedTimeMicros
      @whole_iter_dt = end_time - @start_time
    end
  end
  
  
  
  include RubyOF::Graphics
  def on_draw
    
    
    
    # NOTE: need live coding before I can fiddle with graphics code
    # don't need time scrubbing quite yet, just need to be able to change parameters at runtime
    
    # line_height = 38
    
    
    # screen_print(font: @fonts[:monospace], color: @text_fg_color,
    #              string: "hello world!",
    #              position: origin+CP::Vec2.new(0,line_height*0))
    
    # ^ if you bind the font texture here before drawing the rectangular mesh below, then the mesh will be invisible. not sure why. likely some bug is happening with textures?
    
    
    
    
    
    # RubyOF::CPP_Callbacks.render_material_editor(
    #   @w.cpp_ptr["materialEditor_mesh"],
    #   @w.cpp_ptr["materialEditor_shader"], "material_editor",
      
    #   @fonts[:monospace].font_texture,
    #   @w.cpp_ptr["display_fg_texture"], # <-- no longer available
      
    #   20, 500, 300, 300 # x,y,w,h
    # )
    
    
    
    
    
    
    
    # # 
    # # render sprites
    # # (draw behind @display, to use that area as a mask)
    # # 
    # # ofPushStyle()
    
    # # ofSetColor(RubyOF::Color.hex(0xff0000))
    
    # # pos in char grid
    # char_pos = CP::Vec2.new(@char_width_pxs*10, @line_height*18) 
    
    # # offset by 1/8 of a character (width of smallest block char division)
    # offset   = CP::Vec2.new(@char_width_pxs/8 * 5, 0)
    
    # # final pixel position on screen
    # pos = @display_origin_px + CP::Vec2.new(0,-1) + char_pos + offset
    
    # # @fonts[:monospace].draw_string(@sprite, pos.x, pos.y)
      
    #   @fonts[:monospace].draw_string(@hbar['1/8'], pos.x, pos.y)
      
    #   offset   = CP::Vec2.new(@char_width_pxs/8 * 50, 0)
    #   p2 = pos + offset
    #   @fonts[:monospace].draw_string(@hbar['1/8'], p2.x, p2.y)
      
    #   offset   = CP::Vec2.new(@char_width_pxs/8 * 50*2, 0)
    #   p2 = pos + offset
    #   @fonts[:monospace].draw_string(@hbar['1/8'], p2.x, p2.y)
      
    #   offset   = CP::Vec2.new(@char_width_pxs/8 * 50*3, 0)
    #   p2 = pos + offset
    #   @fonts[:monospace].draw_string(@hbar['1/8'], p2.x, p2.y)
      
    #   offset   = CP::Vec2.new(@char_width_pxs/8 * 50*4, 0)
    #   p2 = pos + offset
    #   @fonts[:monospace].draw_string(@hbar['1/8'], p2.x, p2.y)
      
    #   offset   = CP::Vec2.new(@char_width_pxs/8 * 50*5, 0)
    #   p2 = pos + offset
    #   @fonts[:monospace].draw_string(@hbar['1/8'], p2.x, p2.y)
    
    # # ofPopStyle()
    
    
    
    # 
    # render text display
    # 
    
    @display.draw()
  end
  
  
  
  
  
  def key_pressed(key)
    @input_handler.key_pressed(key)
  end
  
  def key_released(key)
    @input_handler.key_released(key)
  end
  
  
  
  # 
  # mouse prints position in character grid to STDOUT
  # 
  
  def mouse_moved(x,y)
    # p "mouse position: #{[x,y]}.inspect"
  end
  
  def mouse_pressed(x,y, button)
    # p [:pressed, x,y, button]
    
    mouse_to_char_display_pos(@mouse, x,y)
  end
  
  def mouse_dragged(x,y, button)
    # p [:dragged, x,y, button]
    mouse_to_char_display_pos(@mouse, x,y)
    # puts @mouse
  end
  
  def mouse_released(x,y, button)
    # p [:released, x,y, button]
  end
  
  
  
  # this is for drag-and-drop, not for mouse dragging
  def drag_event(files, position)
    p [files, position]
    
  end
  
  
  def on_exit
    # puts @draw_durations.join("\t")
    if RB_SPIKE_PROFILER.enabled?
      RB_SPIKE_PROFILER.disable
    end
  end
  
  
  
  
  private
  
  def mouse_to_char_display_pos(pos, x,y)
    pos.x = x
    pos.y = y
    
    tmp = ( pos - @display_origin_px - @bg_offset )
    
    pos.x = (tmp.x / @char_width_pxs)
    pos.y = (tmp.y / @line_height)
  end
  
  
  
  def screen_print(font:, string:, position:, color: )
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, 0)
      
      ofSetColor(color)
      
      # ofLoadViewMatrix(const glm::mat4 & m) # <- bound in Graphics.cpp
      
      x,y = [0,0]
      vflip = true
      text_mesh = font.get_string_mesh(string, x,y, vflip)
      text_mesh.draw()
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      font.font_texture.unbind
    end
    
  end
  
  
end





CUSTOM_PROF = TracePoint.new(:c_call) do |tp|
  # event = tp.event.to_s.sub(/(.+(call|return))/, '\2').rjust(6, " ")
  
  # inspect_this = 
  #   case tp.self
  #   when CharMappedDisplay
  #     "CharMappedDisplay<>"
  #   when CharMappedDisplay::ColorHelper
  #     "CharMappedDisplay::ColorHelper<>"
  #   else
  #     tp.self.inspect
  #   end
  
  # message = "#{event} of #{tp.defined_class}##{tp.callee_id} from #{tp.path.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")}:#{tp.lineno}"
  
  # # if you call `return` on any non-return events, it'll raise error
  # if tp.event == :return || tp.event == :c_return
  #   inspect_return = 
  #     case tp.return_value
  #     when CharMappedDisplay
  #       "CharMappedDisplay<>"
  #     when CharMappedDisplay::ColorHelper
  #       "CharMappedDisplay::ColorHelper<>"
  #     else
  #       tp.return_value.inspect
  #     end
    
  #   message += " => #{inspect_return}" 
  # end
  # puts(message)
  
  
  printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class
end



def custom_profiler() # &block
  CUSTOM_PROF.enable do
    yield
  end
end


  
TRACER = TracePoint.new(:call, :return, :c_return) do |tp|
  # event = tp.event.to_s.sub(/(.+(call|return))/, '\2').rjust(6, " ")
  
  # inspect_this = 
  #   case tp.self
  #   when CharMappedDisplay
  #     "CharMappedDisplay<>"
  #   when CharMappedDisplay::ColorHelper
  #     "CharMappedDisplay::ColorHelper<>"
  #   else
  #     tp.self.inspect
  #   end
  
  # message = "#{event} of #{tp.defined_class}##{tp.callee_id} from #{tp.path.gsub(/#{GEM_ROOT}/, "[GEM_ROOT]")}:#{tp.lineno}"
  
  # # if you call `return` on any non-return events, it'll raise error
  # if tp.event == :return || tp.event == :c_return
  #   inspect_return = 
  #     case tp.return_value
  #     when CharMappedDisplay
  #       "CharMappedDisplay<>"
  #     when CharMappedDisplay::ColorHelper
  #       "CharMappedDisplay::ColorHelper<>"
  #     else
  #       tp.return_value.inspect
  #     end
    
  #   message += " => #{inspect_return}" 
  # end
  # puts(message)
  
  
  printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class

  
end

def trace() # &block
  TRACER.enable do
    yield
  end
end


require 'ruby-prof'
def run_profiler() # &block
  # PROFILER.enable do
  #   yield
  # end
  
  profile = RubyProf.profile do
    yield
  end
  
  printer = RubyProf::FlatPrinter.new(profile)
  
  printer.print(STDOUT, :min_percent => 2)
end

# https://gist.github.com/lpar/1032297#file-timeout-rb-L37
BUFFER_SIZE = 30
def run_with_timeout(command, timeout, tick)
  output = ''
  begin
    # Start task in another thread, which spawns a process
    stdin, stderrout, thread = Open3.popen2e(command)
    # Get the pid of the spawned process
    pid = thread[:pid]
    start = Time.now

    while (Time.now - start) < timeout and thread.alive?
      # Wait up to `tick` seconds for output/error data
      Kernel.select([stderrout], nil, nil, tick)
      # Try to read the data
      begin
        output << stderrout.read_nonblock(BUFFER_SIZE)
      rescue IO::WaitReadable
        # A read would block, so loop around for another select
      rescue EOFError
        # Command has completed, not really an error...
        break
      end
    end
    # Give Ruby time to clean up the other thread
    sleep 1

    if thread.alive?
      # We need to kill the process, because killing the thread leaves
      # the process alive but detached, annoyingly enough.
      Process.kill("TERM", pid)
    end
  ensure
    stdin.close if stdin
    stderrout.close if stderrout
  end
  return output
end

def run_c_profiler
  start = RubyOF::Utils.ofGetElapsedTimeMicros
  pid = Process.pid
  thr = Thread.new do
    now = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # min_delay = msec(3+16*60)
    # max_delay = msec(16+16*60)
    # rand_delay = ((max_delay - min_delay)*rand + min_delay).to_i
    # while now - start < rand_delay
    #   now = RubyOF::Utils.ofGetElapsedTimeMicros
    #   sleep(1)
    # end
    
    # # puts run_with_timeout('echo #{ENV["ROOT_PASSWORD"]} | sudo -S gdb -ex "set pagination 0" -ex "thread apply all bt" -batch -p '+"#{pid}", 5, 0.1)
    
    Dir.chdir GEM_ROOT/'vendor'/'quickstack-0.10-7' do
      
    #   run_with_timeout('./quickstack -f -p '+"#{pid}", 5, 0.1)
      puts `echo #{ENV["ROOT_PASSWORD"]} | sudo -S ./quickstack -f -p #{pid}`
    end
  end
  
  yield
  
  thr.join
end


RB_SPIKE_PROFILER = TracePoint.new(:call, :return, :c_call, :c_return) do |tp|
  
  # printf "%8s %s:%-2d %10s %8s\n", tp.event, tp.path.split("/").last, tp.lineno, tp.callee_id, tp.defined_class
  
  
  $spike_profiler_i ||= 0
  $spike_profiler_stack ||= Array.new
  
  flag = !([StateMachine].any?{|x| tp.defined_class.to_s == x.to_s })
  # (can't block Kernel - too many false positives)
  # flag = true
  
  # p tp.methods
  # puts tp.binding.source_location
  # ^ not defined in ruby 2.5 - but it is available in 2.7
  #   (not in backports either, so that's a dead end for now)
  
  case tp.event
  # when :call
  when :call, :c_call
    
    if $spike_profiler_i >=0 
      if flag
        # # puts "enter"
        # file_info = "#{tp.path.split('/').last}:#{tp.lineno}"
        method = "#{tp.defined_class}##{tp.callee_id}"
        # puts " #{$spike_profiler_stack.size}) #{method}"
        
        # # if method == "CharMappedDisplay#draw"
        # #   $spike_profiler_reset = true
        # # end
        
        # if method == "Array#index"
        #   puts tp.path.split('/').last
        #   puts caller if tp.path.split('/').last == 'char_mapped_display.rb'
        # end
      
        # $spike_profiler_stack << RubyOF::Utils.ofGetElapsedTimeMicros
        RubyOF::CPP_Callbacks.SpikeProfiler_begin(method)
      end
    end
    
    
    # puts ">> #{$spike_profiler_i}"
    
    # $spike_profiler_stack << RubyOF::Utils.ofGetElapsedTimeMicros
    $spike_profiler_i += 1
    
  # when :return
  when :return, :c_return
    
    if $spike_profiler_i > 0 
      if flag
        # file_info = "#{tp.path.split('/').last}:#{tp.lineno}"
        
        
        # # puts "return   #{tp.defined_class}##{tp.callee_id}"
        # start_time = $spike_profiler_stack.pop
        # now = RubyOF::Utils.ofGetElapsedTimeMicros
        # # puts start_time.inspect
        
        # dt = now - start_time
        # puts " #{$spike_profiler_stack.size})   dt = #{dt}"
        RubyOF::CPP_Callbacks.SpikeProfiler_end()
      end
      
      
    end
    
    # if $spike_profiler_reset and $spike_profiler_stack.size == 0
    #   $spike_profiler_reset = false
    #   puts "\n"*7
    # end
    
    $spike_profiler_i -= 1
    
    # puts "<< #{$spike_profiler_i}"
  end
  
end

def spike_profiler() # &block
  RB_SPIKE_PROFILER.enable do
    yield
  end
end


  
  
