require 'objspace'

class View
  include RubyOF::Graphics
  
  def initialize(controller)
    @controller = controller
    on_reload
  end
  
  def on_reload
    @fonts = Hash.new
    
    @fonts[:monospace] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        x.path = "DejaVu Sans Mono"
        x.size = 23
        x.add_alphabet :Latin
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
    
    
    @text_color ||= RubyOF::Color.new.tap do |c|
      c.r, c.g, c.b, c.a = [80, 80, 80, 255]
    end
    
    
    
    @colors = 5.times.collect{ RubyOF::Color.new }
    
    @colors[0].tap do |c|
      c.r, c.g, c.b, c.a = [80, 80, 80, 255]
    end
    
    @colors[1].tap do |c|
      c.r, c.g, c.b, c.a = [120, 120, 120, 255]
    end
    
    @colors[2].tap do |c|
      c.r, c.g, c.b, c.a = [57-35, 204-35, 221-35, 255]
    end
    
    @colors[3].tap do |c|
      c.r, c.g, c.b, c.a = [100, 80, 200, 255]
    end
    
    @colors[4].tap do |c|
      c.r, c.g, c.b, c.a = [200, 80, 80, 255]
    end
  end
  
  def update
    
  end
  
  def draw
    # y+ is down
    
    # screen_print(@fonts[:english],  "hello world!", CP::Vec2.new(50,300))
    
    @fonts[:monospace].tap do |font|
      start = CP::Vec2.new(70,450)
      
      
      
      # display history information over time
      var_names = [:@main_code, :@core_space, :@input_history]
      var_values  = 
        var_names.collect do |sym|
          @controller.instance_variable_get sym
        end
      
      vars = var_names.zip(var_values).to_h
      
      line_height = 35
      em = 20
      
      col2_x = 13
      col3_x = 20
      
      value = vars[:@core_space].inner.instance_variable_get(:@value).inspect
      
      screen_print(font: font, color: @colors[0],
                     string: "state: #{@controller.execution_state}\nvalue: #{value}",
                     position: start + CP::Vec2.new(0, -line_height*3))
      
      
      # == position pointer == 
      i = @controller.i
      screen_print(font: font, color: @colors[4],
                   string: "|\nV",
                   position: start + CP::Vec2.new(em*col3_x-7 + em*(i*2),-line_height*2))
      
      # == section titles == 
        screen_print(font: font, color: @colors[0],
                     string: '[    ]',
                     position: start)
        screen_print(font: font, color: @colors[3],
                     string: ' 0000',
                     position: start)
        screen_print(font: font, color: @colors[4],
                     string: '->',
                     position: start+CP::Vec2.new(-1*em*2,0))
        
        
        screen_print(font: font, color: @colors[0],
                     string: "size",
                     position: start + CP::Vec2.new(em*(col2_x+1)-3, 0))
      
      # FIXME: better method to get the full 'length' of the controller i
      # FIXME: change numbers to smaller proportional font so they sit over the 'x' marks, even with 2 or 3 digit numbers
        # (those numbers should be centered on the column, so you need to start using not only different fonts, but properties of fonts / text)
      length = @controller.instance_variable_get(:@branch_i)
      length ||= @controller.i
      (0..length).each do |i|
        label = i.to_s
        screen_print(font: font, color: @colors[3],
                     string: label,
                     position: start + CP::Vec2.new(em*col3_x-7 + em*(i*2), 0))
      end
      
      
      # FIXME: Use compressed format for non-active timelines
        # stack 3 symbols: O, X, _
        # one symbol for each type of collection (code, space, input)
        # s.t. you can have a single row of characters (like a minimized mode)
      # == core data output == 
      var_names.each_with_index do |sym,i|
        screen_print(font: font, color: @colors[2],
                     string: sym.to_s,
                     position: start + CP::Vec2.new(0, line_height*(i+1)))
        
        
        
        screen_print(font: font, color: @colors[1],
                     string: "(    )",
                     position: start + CP::Vec2.new(em*col2_x, line_height*(i+1)))
        
        screen_print(font: font, color: @colors[3],
                     string: vars[sym].length.to_s.rjust(5),
                     position: start + CP::Vec2.new(em*col2_x, line_height*(i+1)))
        
        
      # FIXME: put '_' in columns where there is no data, rather than just leaving it blank 
        vars[sym].length.times do |j|
          screen_print(font: font, color: @colors[0],
                       string: 'x',
                       position: start + CP::Vec2.new(em*col3_x-7 + em*(j*2), line_height*(i+1)))
        end
      end
      
      
      # cache = live_code.instance_variable_get :@cache
      
      # length = @controller.instance_variable_get(:@branch_i)
      # length ||= @controller.i
      
      # (0..(length)).collect{ |i|
      #   [live_code, core_space, user_input].collect{ |x|
      #     x.instance_variable_get(:@cache)[i]
      #   }
      # }.each_with_index do |args, x|
      #   args.each_with_index do |timepoint, y|
          
      #     screen_print(font, 
      #                  (timepoint.nil? ?  '_' : 'x'),
      #                  start + CP::Vec2.new(x*20,y*40))
          
      #   end
      # end
      
      
    end
    
    # puts "--- get memory"
    @fonts[:monospace].tap do |font|
      origin = CP::Vec2.new(500,112)
      line_height = 38
      
      screen_print(font: font, color: @colors[0],
                   string: "ram usage",
                   position: origin+CP::Vec2.new(0,line_height*0))
      
      # FIXME: mem_size(@controller) causes major FPS dips as history queue gets longer (> 100 items). [FPS dropping to 20-30 instead of 60]. This is likely because the tree of items to examine is getting much bigger, an the entire tree must be traversed all the time. Could be much smarter, saving known memory values, and only updating the count where the data is actually being changed / added.
        # but even with that disabled, after abount 500 entries, things stay really slow.
        # at that point, it seems that even attempting to display the UI for how many time points have been saved becomes prohibitive
        # need to make the UI rendering faster as well
      
      # TODO: right align numbers using lpad or something
      # TODO: show memory usage as graph over time (useful for #memsize_of_all, which seems to fluctuate periodically)
      size = mem_size(@controller)
      screen_print(font: font, color: @colors[0],
                   string: "local usage: #{format_number(size/1000).rjust(8)} kb",
                   position: origin+CP::Vec2.new(0,line_height*1))
      
      size_all = ObjectSpace.memsize_of_all
      screen_print(font: font, color: @colors[0],
                   string: "total usage: #{format_number(size_all/1000).rjust(8)} kb",
                   position: origin+CP::Vec2.new(0,line_height*2))
    end
  end
  
  
  def screen_print(font:, string:, position:, z:1, color: @text_color)
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(position.x, position.y, z)
      
      ofSetColor(color)
      
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
  
  # size in bytes (recursive)
  # WARNING: calling every frame may cause memory usage to explode
  def mem_size(x)
    # TODO: convert this proc to a helper function or similar. Don't want to be defining this proc again and again all the time. It's just a nice way to prototype the idea.
    foo = ->(x){ ObjectSpace.constants.any?{|const| x.is_a? ObjectSpace.const_get(const) }}
    
    # Don't examine class definition space: Class definitions have a bunch of weird stuff inside. Not gonna measure that.
    # Need to avoid dependency loops - Proc and Fiber both loop back, because they reference lines of code defined in another class / file.
    # Don't examine ObjectSpace classes - those also tend to cause loops
    if x.is_a? Class or x.is_a? Proc or x.is_a? Fiber or foo[x]
      # puts "base case"
      ObjectSpace.memsize_of(x)
    else
      # puts "recursive case: examine #{x.class} #{x.object_id}"
      ObjectSpace.memsize_of(x) +
      ObjectSpace.reachable_objects_from(x).map{|x| mem_size(x) }.reduce(&:+)
    end
  end
  
  def format_number(number, digits_per_group=3, delimiter=',')
    number.to_s.each_char.reverse_each
    .each_slice(digits_per_group).collect{|chunk| chunk.reverse.join() }
    .reverse.join(delimiter)
    
  end

end

