
class BlenderObject
  attr_accessor :name
  attr_accessor :dirty
  
  def initialize
    @dirty = false
      # if true, tells system that this datablock has been updated
      # and thus needs to be saved to disk
  end
end
