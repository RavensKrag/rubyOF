# external API to access history data via @world.history
# control writing / loading data on dynamic entities over time
class History
  # TODO: use named arguments, because the positions are extremely arbitrary
  def initialize(pixels, texture, cache)
    @buffer = HistoryBuffer.new
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
    @max_length = 100
    @buffer.allocate(@pixels.width, @pixels.height, @max_length)
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
    new_buffer = @buffer.dup
    return History.new(new_buffer, @cache)
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
    
    # @buffer.copy_frame(frame_index, @pixels)
    # @cache.load @pixels
    
  end
  
  def snapshot_gamestate_at(frame_index)
    
    # # if we're supposed to save frame data (not time traveling)
    
    # # then try to write the data
    # if @cache.update @pixels
    #   # if data was written...
      
    #   # ...then send it to the GPU
    #   @texture.load_data @pixels
      
    #   # ^ for dynamic entites, need [ofFloatPixels] where each communicates with the same instance of ofTexture
    #   # + one ofTexture for static entites
    #   # + one for dynamic entites
    #   # + then an extra one for rendering ghosts / trails / onion skinning of dynamic entities)
    # end
    
    # # always save a copy in the history buffer
    # # (otherwise the buffer could have garbage at that timepoint)
    # @buffer[frame_index] = @pixels
    
    
    # if @i.nil? || frame_index > @i
    #   @i = frame_index
    # end
  end
  
  
  
  
  
  
  
  # store the data needed for history
  class HistoryBuffer
    def initialize
      @buffer = RubyOF::FloatPixels.new
      
      @frame_width = nil
      @frame_height = nil
      
      @size = nil
    end
    
    def allocate(frame_width, frame_height, max_num_frames)
      @frame_width = frame_width
      @frame_height = frame_height
      
      @size = max_num_frames
      
      @buffer.allocate(@frame_width, @frame_height*@size)
      @buffer.flip_vertical
    end
    
    def size
      return @size
    end
    
    alias :length :size
    
    # FIXME: recieving index -1
    # (should I interpret that as distance from the end of the buffer, or what? need to look into the other code on the critical path to figure this out)
    
    # set data in history buffer on a given frame
    def []=(frame_index, frame_data)
      raise "Memory not allocated. Please call #allocate first" if @size.nil?
      
      raise IndexError, "Index #{frame_index} outside of array bounds: 0..#{@size-1}" unless frame_index >= 0 && frame_index <= @size-1
      
      # TODO: update @size if auto-growing the currently allocated segment
      
      x = 0
      y = frame_index*@frame_height
      frame_data.paste_into(@buffer, x,y)
    end
    
    # copy data from buffer into another image
    def copy_frame(frame_index, out_image)
      raise "Memory not allocated. Please call #allocate first" if @size.nil?
      
      expected_size = [@frame_width, @frame_height]
      output_size = [out_image.width, out_image.height]
      raise "Output image is the wrong size. Recieved #{output_size.inspect} but expected #{expected_size.inspect}" if expected_size != output_size
      
      w = @frame_width
      h = @frame_height
      
      x = 0
      y = frame_index*@frame_height
      
      @buffer.crop_to(out_image, x,y, w,h)
      # WARNING: ofPixels#cropTo() re-allocates memory, so I probably need to implement a better way, but this should at least work for prototyping
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


