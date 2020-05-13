
# stores the main logic and data of the program

# stuff to load just once
require LIB_DIR/'input_handler.rb'
require LIB_DIR/'sequence_memory.rb'
require LIB_DIR/'char_mapped_display.rb'

# stuff to live load ('load' allows for reloading stuff)
load LIB_DIR/'looper_pedal.rb'

# class definition


class Core
  def initialize(window)
    @w = window
  end
  
  def on_reload
    setup()
  end
  
  
  def setup
    @first_draw = true
    
    
    @midi_msg_memory = SequenceMemory.new
    @input_handler = InputHandler.new
    
    
    
    @fonts = Hash.new
    
    @fonts[:monospace] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        x.path = "DejaVu Sans Mono"
        x.size = 23
        x.add_alphabet :Latin
        x.add_unicode_range :BlockElement
      end
    
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
    
    
    
    @display = CharMappedDisplay.new(@fonts[:monospace], 20*3, 18*1)
    # @display.autoUpdateColor_bg(false)
    # @display.autoUpdateColor_fg(false)
    
    # clear out the garbage bg + test pattern fg
    @display.colors.each_with_index do |bg_c, fg_c, pos|
      bg_c.r, bg_c.g, bg_c.b, bg_c.a = ([(0.5*255).to_i]*3 + [255])
      fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.1*255).to_i]*3 + [255])
    end
    
    test_display = Proc.new do
      @display.print_string(5, "hello world!")
      .each do |pos|
        @display.bg_colors.pixel pos do |c|
           c.r, c.g, c.b, c.a = [0, 0, 255, 255]
        end
      end
      
      
      @display.print_string(CP::Vec2.new(55, 5), "spatial inputs~")
      @display.print_string(CP::Vec2.new(7, 5), "spatial inputs~")
      .each do |pos|
        @display.bg_colors.pixel pos do |c|
           c.r, c.g, c.b, c.a = [255, 0, 0, 255]
        end
      end
      
      @display.print_string(CP::Vec2.new(0, 17), "bottom clip")
      @display.print_string(CP::Vec2.new(0, 18), "this should not print")
      
      
      msg = "gets cut off somewhere in the middle"
      @display.print_string(CP::Vec2.new(30, 9), msg)
      .each do |pos|
        @display.bg_colors.pixel pos do |c|
          c.r, c.g, c.b, c.a = [255, 0, 0, 255]
        end
      end
      # ^ Enumerator stops at end of display where the text was clipped
      
      
      
      
      @display.colors.pixel CP::Vec2.new(10,10) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = [255, 0, 0, 255]
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0, 0, 255, 255]
      end
      
      # @display.colors.pixel CP::Vec2.new(50,50) do |bg_c, fg_c|
      #   bg_c.r, bg_c.g, bg_c.b, bg_c.a = [255, 0, 0, 255]
      #   fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0, 0, 255, 255]
      # end
    end
    
    
    
    
    
    
    # clear the area where midi message data will be drawn
    
    # CP::BB
    # l,b,r,t
    x = 0
    y = 0
    w = 18
    h = 10
    @midi_data_bb = CP::BB.new(x,y, x+w,y+h)
    
    @display.colors.each_with_index do |bg_c, fg_c, pos|
      if @midi_data_bb.contain_vect? pos
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = [0xb6, 0xb1, 0x98, 0xff]
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0x32, 0x31, 0x2a, 255]
      end
    end
    
    (0..(@midi_data_bb.t)).each do |i|
      @display.print_string(CP::Vec2.new(0, i), " "*(@midi_data_bb.r+1))
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
    @looper_pedal.setup
    
    btn_id = 'x'.codepoints.first
    @input_handler.register_callback(btn_id, &@looper_pedal.button_handler)
    
    
    
    
    
    
  end
  
  def update
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
    
    
    
    
    
    
    
    
    
    
    lilac       = [0xf6, 0xbf, 0xff, 0xff]
    pale_blue   = [0xa2, 0xf5, 0xff, 0xff]
    pale_green  = [0x93, 0xff, 0xbb, 0xff]
    pale_yellow = [0xff, 0xfc, 0xac, 0xff]
    
    live_colorpicker = @w.cpp_ptr["colorPicker_color"]
    
    color_to_a = ->(c){
      [c.r,c.g,c.b,c.a]
    }
    
    
    # write all messages in buffer to the character display
    # TODO: need live coding ASAP for this
    
    # TODO: clear an entire zone of characters with "F" because if code crashes (in live load mode) in this section, weird glitches could happen
    # (or just let them happen - it could be pretty!)
    
    # TODO: need a way to shift an existing block of text in the display buffer
    
    
    # 
    # show MIDI note data
    # 
    anchor = CP::Vec2.new(@midi_data_bb.l, @midi_data_bb.b)
    
    @display.print_string(
      anchor+CP::Vec2.new(0,0), "b1 b2 b3  deltatime"
    ).each do |pos|
      @display.fg_colors.pixel pos do |fg_c| 
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = [0xf6, 0xff, 0xf6, 255]
        # fg_c.r, fg_c.g, fg_c.b, fg_c.a = pale_green
        # fg_c.r, fg_c.g, fg_c.b, fg_c.a = color_to_a[live_colorpicker]
      end
    end
      
    
    @w.cpp_val["midiMessageQueue"].each_with_index do |midi_msg, i|
      
      @display.print_string(anchor+CP::Vec2.new(0,i+1), midi_msg[0].to_s(16))
      
      @display.print_string(anchor+CP::Vec2.new(3,i+1), midi_msg[1].to_s(16))
      
      @display.print_string(anchor+CP::Vec2.new(6,i+1), midi_msg[2].to_s(16))
      
      
      midi_dt = midi_msg.deltatime
        max_display_num = 99999.999
      midi_dt = [max_display_num, midi_dt].min
      
      msg = ("%.3f" % midi_dt).rjust(max_display_num.to_s.length)
      @display.print_string(anchor+CP::Vec2.new(10,i+1), msg)
      
      
    end
    
    
    # 
    # color picker data
    # 
    anchor = CP::Vec2.new(48,0)
    
    @display.print_string(anchor + CP::Vec2.new(0,0), "r  g  b  a ")
    .each do |pos|
      @display.colors.pixel pos do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = [0,0,0,255]
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.5*255).to_i]*3 + [255])
      end
    end
    @w.cpp_ptr["colorPicker_color"].tap do |c|
      output_string = [c.r,c.g,c.b,c.a].map{|x| x.to_s(16) }.join(",")
      
      @display.print_string(anchor + CP::Vec2.new(0,1), output_string)
      .each do |pos|
        @display.colors.pixel pos do |bg_c, fg_c|
          bg_c.r, bg_c.g, bg_c.b, bg_c.a = [c.r, c.g, c.b, c.a]
          fg_c.r, fg_c.g, fg_c.b, fg_c.a = ([(0.5*255).to_i]*3 + [255])
        end
      end
    end
    
    
    
    
    @hbar ||= {
      '8/8' => '█',
      '7/8' => '▉',
      '6/8' => '▊',
      '5/8' => '▋',
      '4/8' => '▌',
      '3/8' => '▍',
      '2/8' => '▎',
      '1/8' => '▏'
    }
    
    @vbar ||= {
      '1/8' => '▁',
      '2/8' => '▂',
      '3/8' => '▃',
      '4/8' => '▄',
      '5/8' => '▅',
      '6/8' => '▆',
      '7/8' => '▇',
      '8/8' => '█'
    }
    
    
    
    
    count = 16 # 128 midi notes, so 16 chars of 8 increments each will cover it
    bg_color = ([(0.5*255).to_i]*3 + [255])
    fg_color = lilac
    
    @display.print_string(CP::Vec2.new(27,14+0), 'x'*count)
    .each do |pos|
      @display.colors.pixel pos+CP::Vec2.new(0,0) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
      
      @display.colors.pixel pos+CP::Vec2.new(0,1) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
    end
    
    @display.print_string(
      CP::Vec2.new(27,14+1), @hbar['8/8']*(count-1)+@hbar['1/8']
    )
    
    
    # TODO: improve interface - CharMappedDisplay#each_index and CharMappedDisplay#colors.pixel (and similar) need new names
    
      # The name #each_index is confusing, because the block var is a vec2 (2d "index") not an int (1D linear index)
      
      # The name #pixel is confusing because it refers to the backend data store, which is not very important. but the question is: what you do call one element of a discrete mesh that holds color data? isn't that what a pixel is? (I mean like, in the abstract sense)
    
    # hmmm drawing a vertical bar is harder, because there's no Enumerators in this direction...
    count = 4
    anchor = CP::Vec2.new(20,15) # bottom left position
    bg_color = ([(0.5*255).to_i]*3 + [255])
    fg_color = pale_yellow
    
    @display.each_index
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
      
      
      @display.colors.pixel pos + CP::Vec2.new(1,0) do |bg_c, fg_c|
        bg_c.r, bg_c.g, bg_c.b, bg_c.a = bg_color
        fg_c.r, fg_c.g, fg_c.b, fg_c.a = fg_color
      end
    end
    
    
  end
  
  include RubyOF::Graphics
  def draw
    ofBackground(200, 200, 200, 255)
    
    
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
    
    @origin ||= CP::Vec2.new(370,500)
    # line_height = 38
    
    
    # screen_print(font: @fonts[:monospace], color: @text_fg_color,
    #              string: "hello world!",
    #              position: origin+CP::Vec2.new(0,line_height*0))
    
    # ^ if you bind the font texture here before drawing the rectangular mesh below, then the mesh will be invisible. not sure why. likely some bug is happening with textures?
    
    
    
    
    
    # @display.reload_shader
    
    z = 5
    @display.draw(@origin, z)
    
    
    
    # RubyOF::CPP_Callbacks.render_material_editor(
    #   @w.cpp_ptr["materialEditor_mesh"],
    #   @w.cpp_ptr["materialEditor_shader"], "material_editor",
      
    #   @fonts[:monospace].font_texture,
    #   @w.cpp_ptr["display_fg_texture"], # <-- no longer available
      
    #   20, 500, 300, 300 # x,y,w,h
    # )
    
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
    p "mouse position: #{[x,y]}.inspect"
  end
  
  def mouse_pressed(x,y, button)
    # p [:pressed, x,y, button]
    
    offset = CP::Vec2.new(0,10) # probably related to font ascender height
    
    out = ( CP::Vec2.new(x,y) - @origin - offset )
    
    out.x = (out.x / @display.char_width_pxs).to_i
    out.y = (out.y / @display.char_height_pxs).to_i
    
    puts out
  end
  
  def mouse_dragged(x,y, button)
    # p [:dragged, x,y, button]
    
    offset = CP::Vec2.new(0,10)
    
    out = ( CP::Vec2.new(x,y) - @origin - offset )
    
    out.x = (out.x / @display.char_width_pxs).to_i
    out.y = (out.y / @display.char_height_pxs).to_i
    
    puts out
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
  
  
  
  def screen_print(font:, string:, position:, z:1, color: @text_fg_color)
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
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
