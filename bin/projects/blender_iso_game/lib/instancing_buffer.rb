
class InstancingBuffer
  attr_reader :pixels, :texture
  
  def initialize
    @pixels = RubyOF::FloatPixels.new
    @texture = RubyOF::Texture.new
    
    @width = 256
    @height = 256
    @pixels.allocate(@width, @height)
    
    @texture.wrap_mode(:vertical => :clamp_to_edge,
                :horizontal => :clamp_to_edge)
    
    @texture.filter_mode(:min => :nearest, :mag => :nearest)
  end
  
  FLOAT_MAX = 1e10
  # https://en.wikipedia.org/wiki/Single-precision_floating-point_format#IEEE_754_single-precision_binary_floating-point_format:_binary32
  # 
  # I want to use 1e37 for this, or the nearest power of two.
  # The true float max is a little bigger, but this is enough.
  # This also allows for using one max for both positive and negative.
  def pack_positions(positions)
    positions.each_with_index do |pos, i|
      x = i / @width
      y = i % @width
      
      # puts pos
      arr = pos.to_a
      # arr = [1,0,0]
      
      magnitude_sq = arr.map{|i| i**2 }.reduce(&:+)
      magnitude = Math.sqrt(magnitude_sq)
      
      data = 
        if magnitude == 0
          posNorm = [0,0,0]
          posNormShifted = posNorm.map{|i| (i+1)/2 }
          
          [*posNormShifted, 0]
        else
          posNorm = arr.map{|i| i / magnitude }
          posNormShifted = posNorm.map{|i| (i+1)/2 }
          
          magnitude_normalized = magnitude / FLOAT_MAX
          
          
          [*posNormShifted, magnitude_normalized]
        end
      
      color = RubyOF::FloatColor.rgba(data)
      # p color.to_a
      @pixels.setColor(x,y, color)
    end
    
    # same logic as above, but need to make sure ofColorFloat
    # RubyOF::CPP_Callbacks.pack_positions(@pixels, @width, @height)
    
    
    # _pixels->getColor(x,y);
    # _tex.loadData(_pixels, GL_RGBA);
    @texture.load_data(@pixels)
    
  end
  
  def max_instances
    return @width*@height
  end
end