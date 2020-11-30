
class ViewportCamera
  attr_reader :name
  attr_accessor :dirty
  
  extend Forwardable
  include RubyOF::Graphics
  
  def initialize
    @name = 'viewport_camera'
    @dirty = false
      # if true, tells system that this datablock has been updated
      # and thus needs to be saved to disk
    
    
    @of_cam = RubyOF::Camera.new
    @scale = 1
  end
  
  def position=(x)
    @of_cam.position = x
    @position = x
  end
  
  def orientation=(x)
    @of_cam.orientation = x
    @orientation = x
  end
  
  def fov=(x)
    @of_cam.fov = x
    @fov = x
  end
  
  def_delegators :@of_cam, :position, :orientation, :fov
  
  # (defaults to viewport size and that works for me)
  
  # def aspect_ratio=(x)
  #   @of_cam.aspect_ratio = x
  # end
  
  def near_clip=(x)
    @of_cam.near_clip = x
    @near_clip = x
  end
  
  def far_clip=(x)
    @of_cam.far_clip = x
    @far_clip = x
  end
  
  def_delegators :@of_cam, :near_clip, 
                           :far_clip
  
  
  attr_accessor :scale # used for orthographic view only
  
  def ortho?
    return self.state?('ORTHO')
  end
  
  
  # 
  # general strategy 
  # 
  
  # in perspective mode use ofCamera,
  # but in othographic mode manually apply transforms
  # (this is a strategy utilized by ofxInfiniteCanvas)
  
  
  
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
  
  
  
  # exact behavior of #begin and #end depends on the state of the camera
  # NOTE: may want to use a state machine here
  
  
  state_machine :state, :initial => 'PERSP' do
    state 'PERSP' do
      def begin(viewport = ofGetCurrentViewport())
        # puts "persp cam"
        @of_cam.begin
      end
      
      
      def end
        @of_cam.end
      end
    end
    
    state 'ORTHO' do
      def begin
        invertY = false;
        
        # puts "ortho cam"
        # puts @scale
        
        # NOTE: @orientation is a quat, @position is a vec3
        
        vp = ofGetCurrentViewport();
        
        ofPushView();
        ofViewport(vp.x, vp.y, vp.width, vp.height, invertY);
        # setOrientation(matrixStack.getOrientation(),camera.isVFlipped());
        lensOffset = GLM::Vec2.new(0,0)
        ofSetMatrixMode(:projection);
        # projectionMat = 
        #   GLM.translate(GLM::Mat4.new(1.0),
        #                 GLM::Vec3.new(-lensOffset.x, -lensOffset.y, 0.0)
        #   ) * GLM.ortho(
        #     - vp.width/2,
        #     + vp.width/2,
        #     - vp.height/2,
        #     + vp.height/2,
        #     @near_clip,
        #     @far_clip
        #   );
        
        
        # use negative scaling to flip Blender's z axis
        # (not sure why it ends up being the second component, but w/e)
        m5 = GLM.scale(GLM::Mat4.new(1.0),
                       GLM::Vec3.new(1, -1, 1))
        
        projectionMat = 
          GLM.ortho(
            - vp.width/2,
            + vp.width/2,
            - vp.height/2,
            + vp.height/2,
            @near_clip,
            @far_clip*@scale
          );
        ofLoadMatrix(projectionMat * m5);
        
        
        
        ofSetMatrixMode(:modelview);
        
        m0 = GLM.scale(GLM::Mat4.new(1.0),
                       GLM::Vec3.new(@scale, @scale, @scale))
        
        m1 = GLM.translate(GLM::Mat4.new(1.0),
                                @position)
        
        m2 = GLM.toMat4(@orientation)
        
        cameraTransform = m1 * m2
        
        modelViewMat = m0 * GLM.inverse(cameraTransform)
        # ^ maybe apply scale here?
        ofLoadViewMatrix(modelViewMat);
        
        
        
        # @scale of about 25 works great for testing purposes with no translation
        
      end
      
      
      def end
        ofPopView();
      end
    end
    
    
    event :use_orthographic_mode do
      transition any => 'ORTHO'
    end
    
    event :use_perspective_mode do
      transition any => 'PERSP'
    end
  end
  
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    {
        'type' => 'viewport_camera',
        'view_perspective' => self.state,
        'rotation' => [
          'Quat',
          @orientation.w, @orientation.x, @orientation.y, @orientation.z
        ],
        'position' => [
          'Vec3',
          @position.x, @position.y, @position.z
        ],
        'fov' => [
          'deg',
          @fov
        ],
        'ortho_scale' => [
          'factor',
          @scale
        ],
        'near_clip' => [
          'm',
          @near_clip
        ],
        'far_clip' => [
          'm',
          @far_clip
        ]
    }
  end
  
  # read from a hash (deserialization)
  # (viewport camera is not a true entity, so the data structure is different)
  def load(data)
    self.position    = GLM::Vec3.new(*(data['position'][1..3]))
    self.orientation = GLM::Quat.new(*(data['rotation'][1..4]))
    
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
      self.use_perspective_mode
      
      self.fov = data['fov'][1]
      
    when 'ORTHO'
      self.use_orthographic_mode
      self.scale = data['ortho_scale'][1]
      # TODO: scale needs to change as camera is updated
      # TODO: scale zooms as expected, but also effects pan rate (bad)
      
      
    when 'CAMERA'
      
      
    end
  end
  
end
