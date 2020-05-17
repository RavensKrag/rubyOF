
# stores the main logic and data of the program

# stuff to load just once
require LIB_DIR/'input_handler.rb'
require LIB_DIR/'sequence_memory.rb'
require LIB_DIR/'live_code_GLSL.rb'

# stuff to live load ('load' allows for reloading stuff)
load LIB_DIR/'char_mapped_display.rb'
load LIB_DIR/'looper_pedal.rb'

# class definition


class Core
  def initialize(window)
    @w = window
  end
  
  def setup
    @first_draw = true
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
    
    
    # 
    # useful unicode characters
    # 
    
    @hbar ||= {
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
    
    @vbar ||= {
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
    
    
    
    @colors = {
      :lilac       => [0xf6, 0xbf, 0xff, 0xff],
      :pale_blue   => [0xa2, 0xf5, 0xff, 0xff],
      :pale_green  => [0x93, 0xff, 0xbb, 0xff],
      :pale_yellow => [0xff, 0xfc, 0xac, 0xff],
    }
    
    
    
    
    
    
    
    @debug = Hash.new # contains debug flags
    
    # @debug[:bar_graph_tests] = true
    
    
    
    
    
    
    # 
    # text display alignment variables
    # 
    
    descender_height = @fonts[:monospace].descender_height.floor
    @line_height = 39
    @char_width_pxs = 19
    @bg_offset = CP::Vec2.new(0,-@line_height-descender_height)
    @bg_scale  = CP::Vec2.new(@char_width_pxs,@line_height)
    
    # @debug[:display_clipping] = true
    # @debug[:align_display_bg] = true
    # @debug[:align_display_fg] = true
    
    
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
    
    
    
    
    
    
    
    @display = CharMappedDisplay.new(@fonts[:monospace], 20*3, 18*1)
    @display_origin_px = CP::Vec2.new(370,500)
    
    @display.autoUpdateColor_bg(false)
    @display.autoUpdateColor_fg(false)
    
    # clear out the garbage bg + test pattern fg
    @display.each_position do |pos|
      @display.background[pos] = RubyOF::Color.rgb([(0.0*255).to_i]*3)
      @display.foreground[pos] = RubyOF::Color.rgb([(1.0*255).to_i]*3)
    end
    
    
    if @debug[:display_clipping]
      @display.print_string(5, "hello world!")
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0, 0, 255] )
      end
      
      
      @display.print_string(CP::Vec2.new(55, 5), "spatial inputs~")
      @display.print_string(CP::Vec2.new(7, 5), "spatial inputs~")
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
      end
      
      @display.print_string(CP::Vec2.new(0, 17), "bottom clip")
      @display.print_string(CP::Vec2.new(0, 18), "this should not print")
      
      
      msg = "gets cut off somewhere in the middle"
      @display.print_string(CP::Vec2.new(30, 9), msg)
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
      end
      # ^ Enumerator stops at end of display where the text was clipped
      
      
      
      pos = CP::Vec2.new(10,10)
      @display.background[pos] = RubyOF::Color.rgb( [255, 0, 0] )
      @display.foreground[pos] = RubyOF::Color.rgb( [0, 0, 255] )
      
      # @display.colors.pixel CP::Vec2.new(50,50) do |bg_c, fg_c|
      #   bg_c.r, bg_c.g, bg_c.b, bg_c.a = [255, 0, 0, 255]
      #   fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0, 0, 255, 255]
      # end
    end
    
    
    if @debug[:align_display_fg]
      corners = [
        CP::Vec2.new(0,0),
        CP::Vec2.new(1,0),
        CP::Vec2.new(1,1),
        CP::Vec2.new(0,1),
        CP::Vec2.new(@display.x_chars, @display.y_chars),
        CP::Vec2.new(0,                @display.y_chars),
        CP::Vec2.new(@display.x_chars, 0               )
      ]
      
      @display.each_position
      .select{ |pos|  pos.x == 0 or pos.x == @display.x_chars-1 }
      .each do |pos|
        @display.foreground[pos] = RubyOF::Color.rgb( [255, 0, 0] )
      end
      
      @display.each_position
      .select{ |pos| pos.y == 0 or pos.x == @display.y_chars-1  }
      .each do |pos|
        @display.foreground[pos] = RubyOF::Color.rgb( [255, 0, 255] )
      end
      
      
      
      
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
      
      @display.each_position
      .select{ |pos|  bb1.contain_vect? pos  }
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0xb6, 0xb1, 0x98] )
        @display.foreground[pos] = RubyOF::Color.rgb( [0x32, 0x31, 0x2a] )
      end
      
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
      
      @display.each_position
      .select{ |pos| bb2.contain_vect? pos }
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0xb6, 0xb1, 0x98] )
        @display.foreground[pos] = RubyOF::Color.rgb( [0x32, 0x31, 0x2a] )
      end
      
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
      
    
      
      
      
      @display.flushColors_fg
    end
    
    
    if @debug[:bar_graph_tests]
    
      # 
      # bar graph tests
      # 
      
      count = 16 # 128 midi notes, so 16 chars of 8 increments each will cover it
      bg_color = ([(0.5*255).to_i]*3 + [255])
      fg_color = @colors[:lilac]
      
      @display.print_string(CP::Vec2.new(27,14+0), 'x'*count)
      .each do |pos|
        offset = CP::Vec2.new(0,0)
        @display.background[pos+offset] = RubyOF::Color.rgba( bg_color )
        @display.foreground[pos+offset] = RubyOF::Color.rgba( fg_color )
        
        offset = CP::Vec2.new(0,1)
        @display.background[pos+offset] = RubyOF::Color.rgba( bg_color )
        @display.foreground[pos+offset] = RubyOF::Color.rgba( fg_color )
      end
      
      @display.print_string(
        CP::Vec2.new(27,14+1), @hbar['8/8']*(count-1)+@hbar['1/8']
      )
      
      
      # hmmm drawing a vertical bar is harder, because there's no Enumerators in this direction...
      count = 4
      anchor = CP::Vec2.new(20,15) # bottom left position
      bg_color = ([(0.5*255).to_i]*3 + [255])
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
        @display.background[pos+offset] = RubyOF::Color.rgba( bg_color )
        @display.foreground[pos+offset] = RubyOF::Color.rgba( fg_color )
      end
    end
    
    
    
    
    
    
    
    # run the "normal" stuff only when all of the debug modes are disabled
    if @debug.keys.empty?
      
      # clear the area where midi message data will be drawn
      
      # CP::BB
      # l,b,r,t
      x = 0
      y = 1
      w = 50
      h = 11
      @midi_data_bb = CP::BB.new(x,y, x+w,y+h)
      
      @display.each_position
      .select{ |pos| @midi_data_bb.contain_vect? pos }
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0xb6, 0xb1, 0x98] )
        @display.foreground[pos] = RubyOF::Color.rgb( [0x32, 0x31, 0x2a] )
      end
      
      
      ((@midi_data_bb.b.to_i)..(@midi_data_bb.t.to_i)).each do |i|
        @display.print_string(CP::Vec2.new(0, i), " "*(@midi_data_bb.r+1))
      end
      
    end
    
    
    
    
    
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
  end
  
  
  def on_reload
    setup()
    @looper_pedal.setup
    
  end
  
  
  
  def update
    # liveGLSL.foo "char_display" do |path_to_shader|
      # @display.reload_shader
    # end
    
    
    # prototype possible smarter live-loading system for GLSL shaders
    
    shader_name = "char_display"
    files = [
      PROJECT_DIR/"bin/data/#{shader_name}.vert",
      PROJECT_DIR/"bin/data/#{shader_name}.frag"
    ]
    
    @shaderIsCorrect ||= nil
    
    if files.any?{|f| @shader_timestamp.nil? or f.mtime > @shader_timestamp } 
      loaded_correctly = @display.reload_shader
      
      
      
      puts "load code: #{loaded_correctly}"
      # ^ apparently the boolean is still true when the shader is loaded with an error???
      
      puts "loaded? : #{@display.shader_loaded?}"
      # ^ this doesn't work either
      
      
      # This is a long-standing issue, open since 2015:
      
      # https://forum.openframeworks.cc/t/identifying-when-ofshader-hasnt-linked/30626
      # https://github.com/openframeworks/openFrameworks/pull/3734
      
      # (the Ruby code I have here is still better than the naieve code, because it prevents errors from flooding the terminal, but it would be great to detect if the shader is actually correct or not)
      
      
      if loaded_correctly
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
    
    
    
    
    
    
    
    @input_handler.update
    
    
    
    # p @w.cpp_val["midiMessageQueue"]
    
    delta = @midi_msg_memory.delta_from_sample(@w.cpp_val["midiMessageQueue"])
    # print "diff size: #{diff.size}  "; p diff.map{|x| x.to_s }
    
    
    
    
    
    delta.each do |midi_msg|
      # case midi_msg[0]
      # when 0x90 # note on
      #   @w.cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+4, midi_msg.velocity)
      #   @w.cpp_ptr["midiOut"].sendNoteOn( 3, midi_msg.pitch+7, midi_msg.velocity)
      #   # puts "ON: #{midi_msg.to_s}"
        
      # when 0x80 # note off
      #   @w.cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+4, midi_msg.velocity)
      #   @w.cpp_ptr["midiOut"].sendNoteOff(3, midi_msg.pitch+7, midi_msg.velocity)
      #   # puts "OFF: #{midi_msg.to_s}"
        
      # end
      
    end
    
    
    
    
    @looper_pedal.update(delta, @w.cpp_ptr["midiOut"])
    
    
    
    
    
    
    live_colorpicker = @w.cpp_ptr["colorPicker_color"]
    
    if @debug.keys.empty?
      
      # write all messages in buffer to the character display
      # TODO: need live coding ASAP for this
      
      # TODO: clear an entire zone of characters with "F" because if code crashes (in live load mode) in this section, weird glitches could happen
      # (or just let them happen - it could be pretty!)
      
      # TODO: need a way to shift an existing block of text in the display buffer
      
      
      # 
      # show MIDI note data
      # 
      anchor = CP::Vec2.new(@midi_data_bb.l, @midi_data_bb.b)
      
      # print header
      @display.print_string(
        anchor+CP::Vec2.new(0,0), "b1 b2 b3  deltatime      pitch      "
      ).each do |pos|
        # @display.foreground[pos] = RubyOF::Color.rgba([0xf6,0xff,0xf6, 255])
        # @display.foreground[pos] = RubyOF::Color.rgba( @colors[:pale_green] )
        # @display.foreground[pos] = RubyOF::Color.rgba(live_colorpicker.to_a)
        
        # @display.background[pos] = RubyOF::Color.rgba(live_colorpicker.to_a)
        @display.background[pos] = RubyOF::Color.rgba([0xc4, 0xcf, 0xff, 0xff])
      end
      
      # dump data on all messages in the queue
      @w.cpp_val["midiMessageQueue"].each_with_index do |midi_msg, i|
        
        # midi bytes
        @display.print_string(anchor+CP::Vec2.new(0,i+1), midi_msg[0].to_s(16))
        @display.print_string(anchor+CP::Vec2.new(3,i+1), midi_msg[1].to_s(16))
        @display.print_string(anchor+CP::Vec2.new(6,i+1), midi_msg[2].to_s(16))
        
        
        # deltatime
        midi_dt = midi_msg.deltatime
          max_display_num = 99999.999
        midi_dt = [max_display_num, midi_dt].min
        
        msg = ("%.3f" % midi_dt).rjust(max_display_num.to_s.length)
        @display.print_string(anchor+CP::Vec2.new(10,i+1), msg)
        
        
        
        # note value (as bar graph)
        count = 16
          # 128 midi notes, so 16 chars of 8 increments each
          # will cover it at 1 fraction per note
        value = 15
        range = 0..127
        bg_color = ([(0.5*255).to_i]*3 + [255])
        fg_color = @colors[:lilac]
        
        full_bars = midi_msg.pitch / 8
        fractions = midi_msg.pitch % 8
        
        bar_graph  = @hbar['8/8']*full_bars
        bar_graph ||= '' # bar graph can be nil if full_bars == 0
        bar_graph += @hbar["#{fractions}/8"]
        
        # @display.print_string(anchor+CP::Vec2.new(20,i+1), " "*count)
        # .each do |pos|          
        #   @display.background[pos] = RubyOF::Color.rgba(bg_color)
        #   @display.foreground[pos] = RubyOF::Color.rgba(fg_color)
        # end
        
        @display.print_string(
          anchor+CP::Vec2.new(20,i+1),
          bar_graph.ljust(count)
        )
        .each do |pos|
          @display.background[pos] = RubyOF::Color.rgba(bg_color)
          @display.foreground[pos] = RubyOF::Color.rgba(fg_color)
        end
        
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
        @display.print_string(
          anchor+CP::Vec2.new(38,i+1),
          status_string
        )
        
        
        # channel
        @display.print_string(
          anchor+CP::Vec2.new(44,i+1),
          "ch#{midi_msg.channel.to_s.ljust(2)}"
          # ^ there are 16 possible midi channels
          #   thus, worse case the channel name has 2 digits in it
        )
        
      end
      
      # bg_color = ([(0.5*255).to_i]*3 + [255])
      # fg_color = @colors[:lilac]
      
      # # l,b,r,t
      # x = 20
      # y = 2
      # w = 16
      # h = 9
      # bb = CP::BB.new(x,y, x+w,y+h)
      # @display.each_position
      # .select{ |pos|  bb.contain_vect? pos  }
      # .each do |pos|
      #   @display.background[pos] = RubyOF::Color.rgba(bg_color)
      #   @display.foreground[pos] = RubyOF::Color.rgba(fg_color)
      # end
      
      # .each do |pos|
      # end
      
      
      
      
      # 
      # color picker data
      # 
      anchor = CP::Vec2.new(48,0)
      
      @display.print_string(anchor + CP::Vec2.new(0,0), "r  g  b  a ")
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0, 0, 0] )
        @display.foreground[pos] = RubyOF::Color.rgb( [(0.5*255).to_i]*3 )
      end
      @w.cpp_ptr["colorPicker_color"].tap do |c|
        output_string = c.to_a.map{|x| x.to_s(16).rjust(2, '0') }.join(",")
        
        @display.print_string(anchor + CP::Vec2.new(0,1), output_string)
        .each do |pos|
          @display.background[pos] = c
          @display.foreground[pos] = RubyOF::Color.rgb( [(0.5*255).to_i]*3 )
        end
        
      end
      
      
      
      # 
      # mouse data
      # 
      
      
      bb = CP::BB.new(40,13, 58,15)
      
      
      @display.each_position
      .select{ |pos|  bb.contain_vect? pos  }
      .each do |pos|
        @display.background[pos] = RubyOF::Color.rgb( [0xb6, 0xb1, 0x98] )
        @display.foreground[pos] = RubyOF::Color.rgb( [0x32, 0x31, 0x2a] )
      end
      
      ((bb.b.to_i)..(bb.t.to_i)).each do |y|
        @display.print_string(CP::Vec2.new(bb.l, y), " "*(bb.r-bb.l+1))
      end
      
      anchor = CP::Vec2.new(bb.l, bb.b)
      
      @display.print_string(anchor+CP::Vec2.new(1,1), "mouse @ ")
      @display.print_string(anchor+CP::Vec2.new(9,1),
        "[" + @mouse.to_a.map{|x| x.to_i.to_s.rjust(2) }.join(', ') + "]"
      )
      
    end
    
    
    
    
    
    
    
    @display.flushColors_bg()
    @display.flushColors_fg()
  end
  
  include RubyOF::Graphics
  def draw
    ofBackground(200, 200, 200, 255)
    ofEnableBlendMode(:alpha)
    
    
    if @first_draw
      # screen_size = read_screen_size("Screen 0")
      # screen_w, screen_h = screen_size["current"]
      # puts "screen size: #{[screen_w, screen_h].inspect}"
      
      puts "---> callback from ruby"
      @w.cpp_ptr["midiOut"].listOutPorts()
      puts "<--- callback end"
      
      
      @first_draw = false
    end
    
    
    
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
    
    
    
    
    
    
    
    # 
    # render text display
    # 
    
    @display.draw(@display_origin_px, @bg_offset, @bg_scale)
    
    
    
    # 
    # text display background alignment test
    # 
    if @debug[:align_display_bg]
      
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
      
      c1 = [(0.5*255).to_i]*3
      c2 = [(0.7*255).to_i]*3
      
      assoc = @display.each_position.group_by{ |pos| pos.y.to_i % 2 }
      
      assoc[0].each{ |pos| @display.background[pos] = RubyOF::Color.rgb( c1 ) }
      assoc[1].each{ |pos| @display.background[pos] = RubyOF::Color.rgb( c2 ) }
      
      
      
      # 
      # text display color alignment test
      # 
    
    end
    
    
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
    
    @mouse = mouse_to_char_display_pos(x,y)
  end
  
  def mouse_dragged(x,y, button)
    # p [:dragged, x,y, button]
    @mouse = mouse_to_char_display_pos(x,y)
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
    
  end
  
  
  
  
  private
  
  def mouse_to_char_display_pos(x,y)
    out = ( CP::Vec2.new(x,y) - @display_origin_px - @bg_offset )
    
    out.x = (out.x / @char_width_pxs).to_i
    out.y = (out.y / @line_height).to_i
    
    return out
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

