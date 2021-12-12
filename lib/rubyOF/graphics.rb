module RubyOF

module Graphics
  def style_stack(&block)
    begin
      ofPushStyle()
      yield
    ensure 
      ofPopStyle()
    end
  end
  
  def matrix_stack(&block)
    begin
      ofPushMatrix()
      yield
    ensure 
      ofPopMatrix()
    end
  end
  
  # do not pass material to block, as material uniforms must all be set before the material is bound
  def using_material(material) # &block
    material.begin

    yield

    material.end
  end


  # TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
  def using_shader(shader) # &block
    shader.begin

    yield shader

    shader.end
  end

  # TODO: add exception handling here, so gl state set by binding shader and textures doesn't leak
  def using_textures(*texture_list)
    texture_list.each_with_index do |tex,i|
      tex.bind(i) unless tex.nil?
    end

    yield *texture_list

    texture_list.each_with_index do |tex,i|
      tex.unbind(i) unless tex.nil?
    end
  end
  
  
  
  
  
  OF_BLENDMODES = [
    :disabled,
    :alpha,
    :add,
    :multiply,
    :screen,
    :subtract,
  ]
  
  alias :ofEnableBlendMode__cpp :ofEnableBlendMode
  private :ofEnableBlendMode__cpp
  def ofEnableBlendMode(mode)
    i = OF_BLENDMODES.index(mode)
    
    raise ArgumentError, "Given blend mode #{mode.inspect} is not a valid blend mode. Please use one of the following: #{OF_BLENDMODES.inspect}" if i.nil?
    
    ofEnableBlendMode__cpp(i)
  end
  
  
  OF_MATRIX_MODES = [
    :modelview,
    :projection,
    :texture
  ] 
  
  alias :ofSetMatrixMode__cpp :ofSetMatrixMode
  private :ofSetMatrixMode__cpp
  def ofSetMatrixMode(mode)
    i = OF_MATRIX_MODES.index(mode)
    
    raise ArgumentError, "Given matrix mode #{mode.inspect} is not a valid matrix mode. Please use one of the following: #{OF_MATRIX_MODES.inspect}" if i.nil?
    
    ofSetMatrixMode__cpp(i)
  end
  
  
  private :ofLoadImage_path_to_ofFloatPixels
  private :ofLoadImage_path_to_ofPixels
  
  def ofLoadImage(pixels, path_to_file)
    case pixels
    when RubyOF::Pixels
      return ofLoadImage_path_to_ofPixels(pixels, path_to_file)
    when RubyOF::FloatPixels
      return ofLoadImage_path_to_ofFloatPixels(pixels, path_to_file)
    end
  end
  
  
end



end
