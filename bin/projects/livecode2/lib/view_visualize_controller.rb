
class View
  include RubyOF::Graphics
  
  def initialize(controller)
    @controller = controller
    
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
      
      
      screen_print(font: font, color: @colors[0],
                   string: "#{@controller.to_s} (starts at 0)",
                   position: start + CP::Vec2.new(0,-100-30))
      
      
      
      
      # display history information over time
      var_names = [:@live_code, :@core_space, :@user_input]
      var_values  = 
        var_names.collect do |sym|
          @controller.instance_variable_get sym
        end
      
      vars = var_names.zip(var_values).to_h
      
      line_height = 35
      em = 20
      
      # == position pointer == 
      i = @controller.i
      screen_print(font: font, color: @colors[4],
                   string: "|\nV",
                   position: start + CP::Vec2.new(em*18-7 + em*(i*2),-line_height*2))
      
      # == section titles == 
        screen_print(font: font, color: @colors[0],
                     string: '[    ]',
                     position: start)
        screen_print(font: font, color: @colors[3],
                     string: ' 0000',
                     position: start)
        
        
        screen_print(font: font, color: @colors[0],
                     string: "size",
                     position: start + CP::Vec2.new(em*12-3, 0))
      
      # FIXME: better method to get the full 'length' of the controller i
      # FIXME: change numbers to smaller proportional font so they sit over the 'x' marks, even with 2 or 3 digit numbers
        # (those numbers should be centered on the column, so you need to start using not only different fonts, but properties of fonts / text)
      length = @controller.instance_variable_get(:@branch_i)
      length ||= @controller.i
      (0..length).each do |i|
        screen_print(font: font, color: @colors[3],
                     string: i.to_s,
                     position: start + CP::Vec2.new(em*18-7 + em*(i*2), 0))
      end
      
      # == core data output == 
      var_names.each_with_index do |sym,i|
        screen_print(font: font, color: @colors[2],
                     string: sym.to_s,
                     position: start + CP::Vec2.new(0, line_height*(i+1)))
        
        
        
        screen_print(font: font, color: @colors[1],
                     string: "(    )",
                     position: start + CP::Vec2.new(em*11, line_height*(i+1)))
        
        screen_print(font: font, color: @colors[3],
                     string: vars[sym].length.to_s.rjust(5),
                     position: start + CP::Vec2.new(em*11, line_height*(i+1)))
        
        
      # FIXME: put '_' in columns where there is no data, rather than just leaving it blank 
        vars[sym].length.times do |j|
          screen_print(font: font, color: @colors[0],
                       string: 'x',
                       position: start + CP::Vec2.new(em*18-7 + em*(j*2), line_height*(i+1)))
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
  
end

