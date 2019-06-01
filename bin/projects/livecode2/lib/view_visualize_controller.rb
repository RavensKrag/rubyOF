
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
        x.size = 30
        x.add_alphabet :Latin
      end
    
    @fonts[:english] = 
      RubyOF::TrueTypeFont.dsl_load do |x|
        # TakaoPGothic
        x.path = "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"
        x.size = 30
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
      c.r, c.g, c.b, c.a = [255, 0, 0, 255]
    end
  end
  
  def update
    
  end
  
  def draw
    # y+ is down
    screen_print(@fonts[:english],  "hello world!", CP::Vec2.new(50,500))
    screen_print(@fonts[:monospace], @controller.to_s, CP::Vec2.new(50,600))
    
    # puts 
  end
  
  
  def screen_print(font, string, pos, z=1)
    
      font.font_texture.bind
    
      ofPushMatrix()
      ofPushStyle()
    begin
      ofTranslate(pos.x, pos.y, z)
      
      ofSetColor(@text_color)
      
      x,y = [0,0]
      vflip = true
      text_mesh = @font.get_string_mesh(string, x,y, vflip)
      text_mesh.draw()
    ensure
      ofPopStyle()
      ofPopMatrix()
      
      font.font_texture.unbind
    end
    
  end
  
end

