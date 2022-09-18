
class BlenderObject
  DATA_TYPE = 'object--EXAMPLE_ONLY--'
  
  attr_accessor :name
  attr_accessor :dirty
  
  def initialize(name)
    @name = name
    
    @dirty = false
      # if true, tells system that this datablock has been updated
      # and thus needs to be saved to disk
      
      # ^ not currently using this flag for exactly this purpose, so need to update comments or increase clarity of purpose in code
  end
  
  # convert to a hash such that it can be serialized with yaml, json, etc
  def data_dump
    raise "Data from instance of #{self.class} could not be dumped because variable @name was not set.\n=> #{self.inspect}" if @name.nil?
    
    {
      'name' =>  @name,
      '.type' => self.class::DATA_TYPE,

      'transform' => self.pack_transform(),
    }
  end
  
  
  
  def pack_transform
    orientation = self.orientation
    position = self.position
    scale = self.scale
    
    {
      'rotation' => [
        'Quat',
        orientation.w, orientation.x, orientation.y, orientation.z
      ],
      'position' => [
        'Vec3',
        position.x, position.y, position.z
      ],
      'scale' => [
        'Vec3',
        scale.x, scale.y, scale.z
      ]
    }
  end
  
  def load_transform(transform)
    self.position    = GLM::Vec3.new(*(transform['position'][1..3]))
    self.orientation = GLM::Quat.new(*(transform['rotation'][1..4]))
    self.scale       = GLM::Vec3.new(*(transform['scale'][1..3]))
  end
  
  
  
  
  def pack_data()
    raise "Need to define #pack_data for all subclasses of BlenderObject. #{self.class}#pack_data not defined.\n(Should override base implementation where this error message is defined)."
  end
  
  def load_data(obj_data)
    raise "Need to define #load_data for all subclasses of BlenderObject. #{self.class}#load_data not defined.\n(Should override base implementation where this error message is defined)."
  end
end
