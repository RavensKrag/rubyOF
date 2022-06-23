# external API to access history data via @world.history
# control writing / loading data on dynamic entities over time
class History
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(pixels, texture, cache, buffer=nil)
    if buffer
      @buffer = buffer
    else
      @buffer = HistoryBuffer.new
    end
      # @buffer : HistoryBuffer object
      # storage is one big image,
      # but API is like an array of images
      
      # ^ list of frames over time, not just one state
      # should combine with FrameHistory#frame_index to get data on a particular frame
      # (I know this needs to save entity data, but it may not need to save mesh data. It depends on whether or not all animation frames can fit in VRAM at the same time or not.)
    
    @pixels = pixels
    @texture = texture
    @cache = cache
    
    
    # @texture : RubyOF::Texture
    @max_length = 0
    @i = nil
  end
  
  def setup
    @max_length = 3600
    @buffer.allocate(@pixels.width, @pixels.height, @max_length)
  end
  
  def buffer_width
    @buffer.frame_width
  end
  
  def buffer_height
    @buffer.frame_height
  end
  
  def max_length
    return @max_length
  end
  
  
  # TODO: properly implement length (needed by FrameHistory - may need to refactor that class instead)
  def length
    if @i.nil?
      return 0
    else
      return @i-1
    end
  end
  
  alias :size :length
  
  
  # TODO: think about how you would implement multiple timelines
  def branch(frame_index)
    new_buffer = @buffer.slice(0..frame_index)
    return History.new(@pixels, @texture, @cache, new_buffer)
  end
  
  
  
  # TODO: consider storing the current frame_count here, to have a more natural interface built around #<< / #push
  # (would clean up logic around setting frame data to not be able to set arbitrary frames, but that "cleaner" version might not actually work because of time traveling)
  
  
  # sketch out new update flow
  
  # Each update with either generate new state, or just advance time.
  # If new state was generated, we need to send it to the GPU to see it.
  
  def load_state_at(frame_index)
    # if we moved in time, but didn't generate new state
      # need to load the proper state from the buffer into the cache
      # because the cache now does not match up with the buffer
      # and the buffer has now become the authoritative source of data.
    
    @buffer.copy_to_frame(frame_index, @pixels)
    @cache.load @pixels
    
  end
  
  def snapshot_gamestate_at(frame_index)
    
    # always save a copy in the history buffer
    # (otherwise the buffer could have garbage at that timepoint)
    @buffer.set_from_frame(frame_index, @pixels)
    
    # TODO: implement a C++ function to copy the image data
      # current code just saves a ruby reference to an existing image,
      # which is not what we want.
      # we want a separate copy of the memory,
      # so that the original @pixels can continue to mutate
      # without distorting what's in the history buffer
    
    
    if @i.nil? || frame_index > @i
      @i = frame_index
    end
  end
  
  
  
  
  
  
  
  # store the data needed for history
  class HistoryBuffer
    attr_reader :frame_width, :frame_height
    
    def initialize
      @buffer = []
      
      @frame_width = nil
      @frame_height = nil
    end
    
    def allocate(frame_width, frame_height, max_num_frames)
      # remember size of each frame stored
      @frame_width = frame_width
      @frame_height = frame_height
      
      # store data
      @buffer = Array.new(max_num_frames)
      @buffer.size.times do |i|
        pixels = RubyOF::FloatPixels.new
        
        pixels.allocate(@frame_width, @frame_height)
        pixels.flip_vertical
        
        @buffer[i] = pixels
      end
      
      # track which entries have valid data
      @valid = Array.new(max_num_frames)
      
    end
    
    def size
      return @buffer.size
    end
    
    alias :length :size
    
    # FIXME: recieving index -1
    # (should I interpret that as distance from the end of the buffer, or what? need to look into the other code on the critical path to figure this out)
    
    # set data in history buffer on a given frame
    def set_from_frame(frame_index, frame_data)
      raise "Memory not allocated. Please call #allocate first" if self.size == 0
      
      raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{self.size-1}" unless frame_index >= 0 && frame_index <= self.size-1
      
      # save data
      @buffer[frame_index].copy_from frame_data
      
      # mark entry as valid
      @valid[frame_index] = true
    end
    
    # copy data from buffer into another image
    def copy_to_frame(frame_index, out_image)
      raise "Memory not allocated. Please call #allocate first" if self.size == 0
      
      expected_size = [@frame_width, @frame_height]
      output_size = [out_image.width, out_image.height]
      raise "Output image is the wrong size. Recieved #{output_size.inspect} but expected #{expected_size.inspect}" if expected_size != output_size
      
      # make sure this image represents a valid state before loading
      if @valid[frame_index]
        out_image.copy_from @buffer[frame_index]
      else
        raise "ERROR: Tried to load render entity history for frame #{frame_index}, but no valid data found in buffer."
      end
      
    end
    
    # Works similarly to Array#slice, but makes a deep copy.
    # Returns a new HistoryBuffer object with only data from the frames within the range.
    def slice(range)
      buf = @buffer[range]
      other = self.class.new
      other.allocate(@frame_width, @frame_height, self.size)
      
      buf.each_with_index do |frame_data, i|
        other.set_from_frame(i, frame_data)
      end
      
      return other
    end
    
    # OpenFrameworks documentation
      # use ofPixels::pasteInto(ofPixels &dst, size_t x, size_t y)
      # 
      # "Paste the ofPixels object into another ofPixels object at the specified index, copying data from the ofPixels that the method is being called on to the ofPixels object at &dst. If the data being copied doesn't fit into the destination then the image is cropped."
      
    
      # cropTo(...)
      # void ofPixels::cropTo(ofPixels &toPix, size_t x, size_t y, size_t width, size_t height)

      # This crops the pixels into the ofPixels reference passed in by toPix. at the x and y and with the new width and height. As a word of caution this reallocates memory and can be a bit expensive if done a lot.
    
  end
  
  
end


