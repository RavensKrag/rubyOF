class LooperPedal
  attr_reader :button_handler
  
  def initialize
    # on first load (but not reload)
    
    @looper_mode = :idle
    @looper = Array.new
    
    
    # button handler must be declared on init, not setup
    # (if re-created on load, it would need to be re-bound in calling code)
    
    # assign handler here, but bind to window outside
    # (that way, the keys bound can all be specified in the same place)
    @button_handler = Proc.new do |btn|
      btn.on_press do
        case @looper_mode 
        when :record
          # record -> playback
          # => stop recording, and switch to playing back the saved recording
          @looper_end = RubyOF::Utils.ofGetElapsedTimeMillis()
          
          
          @looper_mode = :playback
          
        when :playback, :idle
          # playback -> record
          # => start a fresh recording
          @looper.clear
          @looper_fiber = nil
          
          
          @looper_mode = :record
        
        end
        
      end
      
      btn.on_release do
        
      end
      
      btn.while_idle do
        
      end
      
      btn.while_active do
        
      end
    end
    
  end
  
  def setup
    # on reload
    
    @looper_mode = :idle
    @looper.clear
    
    puts "#{self.class} reloaded!"
    
  end
  
  def update(midi_messages, midi_out)
    case @looper_mode
    when :record
      @looper.push *midi_messages
      
    when :playback
      @looper_fiber ||= Fiber.new do 
        @looper_acc = 0
        @looper_i = 0
        
        now = RubyOF::Utils.ofGetElapsedTimeMillis()
        @looper_start = now
        
        
        msg = @looper[@looper_i]
        case msg[0]
        when 0x90 # note on
          midi_out.sendNoteOn( 3, msg.pitch, msg.velocity)
        when 0x80 # note off
          midi_out.sendNoteOff(3, msg.pitch, msg.velocity)
        end
        
        
        loop do
          @looper_i += 1
          @looper_i = 0 if @looper_i >= @looper.length
          
          msg = @looper[@looper_i]
          @looper_acc += msg.deltatime
          
          now = RubyOF::Utils.ofGetElapsedTimeMillis()
          dt = now - @looper_start
          
          until dt >= @looper_acc
            Fiber.yield
            
            now = RubyOF::Utils.ofGetElapsedTimeMillis()
            dt = now - @looper_start
          end
          
          case msg[0]
          when 0x90 # note on
            midi_out.sendNoteOn( 3, msg.pitch, msg.velocity)
          when 0x80 # note off
            midi_out.sendNoteOff(3, msg.pitch, msg.velocity)
          end
          
          
          
          
          # # after final note, wait until the end of the loop clip
          # if @looper_i == @looper.length-1
          #   loop_length = @looper_end - @looper_start
          #   final_acc = loop_length - @looper_acc
            
          #   now = RubyOF::Utils.ofGetElapsedTimeMillis()
          #   dt = now - @looper_start
            
          #   until dt >= final_acc
          #     Fiber.yield
              
          #     now = RubyOF::Utils.ofGetElapsedTimeMillis()
          #     dt = now - @looper_start
          #   end
          # end
          
          
        end
        
        
      end
      
      
      @looper_fiber.resume()
    end
    
  end
  
  def draw
    # no draw right now
    
  end


end
