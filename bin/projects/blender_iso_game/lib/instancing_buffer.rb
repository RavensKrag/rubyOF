
class InstancingBuffer
  attr_reader :pixels, :texture, :width, :height
  
  def initialize(max_instances: 4096)
    @pixels = RubyOF::FloatPixels.new
    @texture = RubyOF::Texture.new
    
    @width = 4
    @height = max_instances
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
  # 
  # (this encodes positions only, where each pixel encodes one normalized vec3, and the alpha channel encodes magnitude. this is the technique used in the "4000 adams" video - link below. this encoding structure is not currently being used, because it does not account for orientation. however, it is useful for animations, so I may revisit it later)
  # 
  # “4,000 Adams at 90 Frames Per Second | Yi Fei Boon”, from the “GameDaily Connect” channel on Youtube. May 26, 2017.
  # https://www.youtube.com/watch?v=rXqKu9uC0f4
  def pack_positions_with_indicies(positions_with_indicies)
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    positions_with_indicies.each do |pos, i|
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
    
    
    # # NOTE: C++ now out of date - need to send index data as well so that I can update only a certain subset of instances if necessary
    
    # # same logic as above, but implemented in C++
    # data = positions_with_indicies.map{|pos,i| pos}.map{|x| x.to_a }.flatten
    # RubyOF::CPP_Callbacks.pack_positions(
    #   @pixels, @width, FLOAT_MAX, data
    # )
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0
    puts "time - pack instances: #{dt.to_f / 1000} ms"
    
    
    
    
    
    t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    # _pixels->getColor(x,y);
    # _tex.loadData(_pixels, GL_RGBA);
    @texture.load_data(@pixels)
    
    t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    dt = t1-t0
    puts "time - instance pixels to texture: #{dt.to_f / 1000} ms"
    
  end
  
  
  def pack_all_transforms(nodes)
    # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    RubyOF::CPP_Callbacks.pack_transforms(
      @pixels, @width, FLOAT_MAX, nodes
    )
    
    # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    # dt = t1-t0
    # puts "time - pack instance positions: #{dt.to_f / 1000} ms"
    
    
    
    # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    @texture.load_data(@pixels)
    
    # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    # dt = t1-t0
    # puts "time - instance pixels to texture: #{dt.to_f / 1000} ms"
    
  end
  
  def max_instances
    # texture encodes one mat4 (transform matrix) per row, for all N entities
    return @height
  end
end
