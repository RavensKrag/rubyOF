
class ViewportCamera
  attr_reader :name
  attr_accessor :dirty
  
  extend Forwardable
  include RubyOF::Graphics
  
  def initialize
    super() # set up state machine
    
    @name = 'viewport_camera'
    @dirty = false
      # if true, tells system that this datablock has been updated
      # and thus needs to be saved to disk
    
    
    @of_cam = RubyOF::OFX::Camera.new
  end
  
  def_delegators :@of_cam, :getModelViewMatrix
  
  def_delegators :@of_cam, :position=, :orientation=, :near_clip=, :far_clip=
  def_delegators :@of_cam, :position,  :orientation,  :near_clip,  :far_clip
  
  def_delegators :@of_cam, :fov=, :aspect_ratio=, :force_aspect_ratio=
  def_delegators :@of_cam, :fov,  :aspect_ratio,  :force_aspect_ratio
  # (aspect ratio defaults to viewport size and that works for me)
  # (for my use case, I don't need to force the aspect ratio)
  
  def_delegators :@of_cam, :ortho_scale=
  def_delegators :@of_cam, :ortho_scale
  
  
  
  def begin(vp = ofGetCurrentViewport())
    @of_cam.begin(vp)
  end
  
  def end
    @of_cam.end
  end
  
  def to_ofxCamera
    return @of_cam
  end
  
  
  VALID_MODES = ['PERSP', 'ORTHO']
  
  def mode
    return @mode
  end
  
  def mode=(new_mode)
    # error handling
    if !VALID_MODES.include? new_mode
      raise "ERROR: '#{new_mode.to_s}' is not a vaild mode name. Should be one of the following: #{VALID_MODES.inspect}"
    end
    
    # switch modes
    # (store mode as string for compability with Blender's api, but ruby API should accept a symbol, because that's what's normal for Ruby)
    current_mode = @mode
    case new_mode
    when 'PERSP'
      # puts "disable ortho"
      @of_cam.disableOrtho()
      @mode = 'PERSP'
    when 'ORTHO'
      # puts "enable ortho"
      @of_cam.enableOrtho()
      @mode = 'ORTHO'
    end
  end
  
  
  
  
  # 
  # general strategy 
  # 
  
  # In perspective mode use a system based on ofCamera (called ofxCamera)
  # but in othographic mode use custom transforms, based on Blender's camera.
  # 
  # (ofxInfiniteCanvas uses a similar strategy, delegating to ofCamera for perspective, but using custom code for orthographic view)
  
  
  
  # 
  # parameters
  # 
  
  # position
  # rotation
  # fov
  # aspect ratio
  # near clip
  # far clip
  
  # ortho scale
  # ortho?
  
  
  
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    rot = self.orientation
    pos = self.position
    
    {
        'type' => 'viewport_camera',
        'view_perspective' => self.mode,
        'rotation' => [
          'Quat',
          rot.w, rot.x, rot.y, rot.z
        ],
        'position' => [
          'Vec3',
          pos.x, pos.y, pos.z
        ],
        'fov' => [
          'deg',
          self.fov
        ],
        'ortho_scale' => [
          'factor',
          self.ortho_scale
        ],
        'near_clip' => [
          'm',
          self.near_clip
        ],
        'far_clip' => [
          'm',
          self.far_clip
        ]
    }
  end
  
  # read from a hash (deserialization)
  # (viewport camera is not a true entity, so the data structure is different)
  def load(data)
    self.position    = GLM::Vec3.new(*(data['position'][1..3]))
    self.orientation = GLM::Quat.new(*(data['rotation'][1..4]))
    
    # puts "position"
    # p self.position
    
    # puts "orientation"
    # p self.orientation
    
    # Viewport camera does not have a scale the way that other entities do.
    # There is a 'scale', but that's listed as 'ortho_scale'
    # and functions quite differently.
    
    self.near_clip   = data['near_clip'][1]
    self.far_clip    = data['far_clip'][1]
    
    # p data['aspect_ratio'][1]
    # @self.setAspectRatio(data['aspect_ratio'][1])
    # puts "force aspect ratio flag: #{@self.forceAspectRatio?}"
    
    # NOTE: Aspect ratio appears to do nothing, which is bizzare
    
    
    # p data['view_perspective']
    case data['view_perspective']
    when 'PERSP'
      # puts "perspective cam ON"
      self.mode = 'PERSP'
      
      self.fov = data['fov'][1]
      
    when 'ORTHO'
      self.mode = 'ORTHO'
      self.ortho_scale = data['ortho_scale'][1]
      p self.ortho_scale
      p @of_cam
      
    when 'CAMERA'
      
      
    end
  end
  
  
  # 
  # YAML serialization interface
  # 
  
  def to_yaml_type
    "!ruby/object:#{self.class}"
  end
  
  def encode_with(coder)
    coder.represent_map to_yaml_type, self.data_dump
  end
  
  def init_with(coder)
    initialize()
    self.load(coder.map)
  end
  
end
