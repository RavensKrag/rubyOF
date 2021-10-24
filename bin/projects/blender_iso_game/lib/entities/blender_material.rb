class BlenderMaterial < RubyOF::OFX::DynamicMaterial
  attr_reader :name
  
  def initialize(name)
    super()
    @name = name
    @shader_timestamp = nil
    
    self.shininess = 64
    
    # Default values from 
    # ext/openFrameworks/libs/openFrameworks/gl/ofMaterial.h
    
    self.diffuse_color  = RubyOF::FloatColor.rgba([0.8, 0.8, 0.8, 1.0])
    # self.ambient_color  = RubyOF::FloatColor.rgba([0.2, 0.2, 0.2, 1.0])
    # self.specular_color = RubyOF::FloatColor.rgba([0.0, 0.0, 0.0, 1.0])
    # self.emissive_color = RubyOF::FloatColor.rgba([0.0, 0.0, 0.0, 1.0])
    
    
    # Defaults, but with 0 alpha channel
    # (all alpha will now come from diffuse, because different components are combined with addition)
    
    self.ambient_color  = RubyOF::FloatColor.rgba([0.2, 0.2, 0.2, 0.0])
    self.specular_color = RubyOF::FloatColor.rgba([0.0, 0.0, 0.0, 0.0])
    self.emissive_color = RubyOF::FloatColor.rgba([0.0, 0.0, 0.0, 0.0])
  end
  
  
  # TODO: implement serialization methods
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    {
        'type' => 'MATERIAL',
        'name' => @name,
        'ambient_color'  => self.ambient_color,
        'diffuse_color'  => self.diffuse_color,
        'specular_color' => self.specular_color,
        'emissive_color' => self.emissive_color,
        'shininess'      => self.shininess
    }
  end
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder.represent_map to_yaml_type, self.data_dump
  end
  
  def init_with(coder)
    initialize(coder['name'])
    
    self.ambient_color  = coder['ambient_color']
    self.diffuse_color  = coder['diffuse_color']
    self.specular_color = coder['specular_color']
    self.emissive_color = coder['emissive_color']
    self.shininess      = coder['shininess']
    
  end
  
  
  
  # Reload specified shaders if necessary and return new timestamp.
  # If the shaders were not reloaded, timestamp remains unchanged.
  def load_shaders(vert_shader_path, frag_shader_path) # &block
    # load shaders if they have never been loaded before,
    # or if the files have been updated
    if @shader_timestamp.nil? || [vert_shader_path, frag_shader_path].any?{|f| f.mtime > @shader_timestamp }
      
      
      vert_shader = File.readlines(vert_shader_path).join("\n")
      frag_shader = File.readlines(frag_shader_path).join("\n")
      
      puts "\n"*2
      puts "-------------"
      puts "reloading vertex and frag shaders for #{@name}"
      self.setVertexShaderSource vert_shader
      self.setFragmentShaderSource frag_shader
      
      
      bShadersLoaded = self.forceShaderRecompilation()
      
      if bShadersLoaded
        @shader_timestamp = Time.now
        # NOTE: the shader source strings *will* be effected by the shader preprocessing pipeline in ofShader.cpp
        
        yield if block_given?
      else
        shader_src_dir = PROJECT_DIR/"bin/glsl"
        
        vert_shader = File.readlines(shader_src_dir/"phong_error.vert").join("\n")
        frag_shader = File.readlines(shader_src_dir/"phong_error.frag").join("\n")
        
        self.setVertexShaderSource vert_shader
        self.setFragmentShaderSource frag_shader
        
        
        puts "using fallback shaders"
        
        @shader_timestamp = Time.now
      end
      
    end
  end
  
  def reset_shaders
    @shader_timestamp = nil
  end
  
end
