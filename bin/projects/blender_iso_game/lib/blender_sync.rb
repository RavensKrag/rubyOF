
class BlenderSync
  MAX_READS = 20
  
  def initialize(message_history, history)
    @message_history = message_history
    @frame_history = history
    
    
    # two-way communication between RubyOF (ruby) and Blender (python)
    # implemented using two named pipes
    @blender_link = ActorChannel.new
    @finished = false
    
    @blender_link.start
    
    
    message = {
      'type' => 'first_setup'
    }
    @blender_link.send(message)
  end
  
  def stop
    puts "stopping sync"
    
    
    message = {
      'type' => 'sync_stopping',
      'history.length' => @frame_history.length
    }
    @blender_link.send message
    
    @blender_link.stop
  end
  
  def reload
    puts "BlenderSync - reload()"
    if @blender_link.stopped?
      puts "BlenderSync: reloading"
      @blender_link.start
      
      message = {
        'type' => 'loopback_reset',
        'history.length'      => @frame_history.length,
        'history.frame_index' => @frame_history.frame_index
      }
      
      @blender_link.send message
    end
  end
  
  def update
    # update_t0 = RubyOF::Utils.ofGetElapsedTimeMicros
    
    
    # @blender_link.send
    # message = @blender_link.take
    
    
    # 
    # read messages from Blender (python)
    # 
    
    while message = @blender_link.take
      # t0 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      # # --- This write is only needed for debugging
      # File.open(PROJECT_DIR/'bin'/'data'/'tmp.json', 'a+') do |f|
      #   f.puts JSON.pretty_generate message
      # end
      # # ---
      
      # p list
      # t1 = RubyOF::Utils.ofGetElapsedTimeMicros
      
      # dt = t1-t0;
      # puts "time - parse json: #{dt}"
      
      
      # send all of this data to history
      @message_history.write message
      
    end
    
    # TODO: reactivate / reimplement history so state is maintained when code reloads
    
    # TODO: merge messages in order to catch up if possible?
      # like, responding to linked window mode is slow, but if we can drop some of the older messages (they're superceeded by the newer messages anyway) then we can maybe stop the framerate from tanking.
    
    # TODO: why can't the viewport be made about 1/4 of my screen size? why does it have to be large to sync with the RubyOF window?
    
    
    @message_history.read do |message|
      yield message
    end
    # ^ this method of merging history can't prevent spikes due to
    #   expensive operations like window sync that take more than 1 frame,
    #   but the old way couldn't deal with that either.
    
    
    
    # update_t1 = RubyOF::Utils.ofGetElapsedTimeMicros
    # dt = update_t1 - update_t0
    # puts "TOTAL UPDATE TIME: #{dt}" if dt > 10
    
    
    # 
    # send messages to Blender (python)
    # 
    if @frame_history.state == :finished
      # needs to be a separate if block,
      # so outer else only triggers when we detect some other state
      if !@finished
        puts "finished --> (send message to blender)"
        message = {
          'type' => 'loopback_finished',
          'history.length' => @frame_history.length
        }
        
        @blender_link.send message
        
        @finished = true
      end
    else
      @finished = false
      # message = {
      #   'type' => 'history.length',
      #   'value' => @frame_history.length
      # }
      
      # @blender_link.send message
      
    end
    
    
  end
  
  def send_to_blender(message)
    @blender_link.send message
  end
  
  def reset
    @blender_link.reset
  end
  
  private
  
  
  
  # Implement an interface similar to ruby's Ractor,
  # which is based on the actor pattern
  class ActorChannel
    def initialize
      @fifo_dir = PROJECT_DIR/'bin'/'run'
    end
    
    
    def start
      # 
      # Open FIFO in main thread then pass to Thread using function closure.
      # This prevents weird race conditions.
      # 
      # Consider this timing diagram:
      #   main thread         @incoming_thread
      #   -----------         -----------
      #   setup               
      #                       File.mkfifo(fifo_path)
      #                       
      #   update (ERROR)
      #                       f_r = File.open(fifo_path, "r+")
      #                       
      #                       ensure: f_r#close
      #                       ensure: FileUtils.rm(fifo_path)
      # 
      # ^ When the error happens in update
      #   f_r has not yet been initialized (f_r == nil)
      #   but the ensure block of @incoming_thread will try close f_r.
      #   This results in an exception, 
      #   which prevents the FIFO from being properly deleted.
      #   This will then cause an error when the program is restarted / reloaded
      #   as a FIFO can not be created where one already exists.
      
      @f_r = File.open(make_fifo(@fifo_dir/'blender_comm'), "r+")
      
      # NOTE: @incoming_port and @outgoing_port always hold JSON-encoded strings, not other types of ruby objects.
      # (see #send and #take for details)
      
      @incoming_port = Queue.new
      
      @incoming_thread = Thread.new do
        begin
          puts "#{self.class}: incoming thread start"
          loop do
            data = @f_r.gets # blocking IO
            @incoming_port << data
          end
        ensure
          puts "#{self.class}: incoming thread stopped"
        end
      end
      
      
      
      
      @outgoing_port = Queue.new
      
      @outgoing_thread = Thread.new do
        puts "#{self.class}: outgoing thread start"
        
        @outgoing_fifo_path = make_fifo(@fifo_dir/'blender_comm_reverse')
        begin
          loop do
            # NOTE: FIFO must be re-opened right after pipe is broken, otherwise we can't detect when writers connect
            
            begin
              if @f_w.nil?
                puts "#{self.class}: opening outgoing pipe"
                
                # clear all messages put into the the buffer
                # while the port was closed
                # puts "clear @outgoing_port"
                # @outgoing_port.clear
                # ^ shouldn't near to clear again
                #   how would anything get into the queue?
                #   if the thread is down, then the system
                #   should not be updating game state, just trying
                #   to load new code / old history to get
                #   into a decent state again
                
                # blocks on open if no writers
                @f_w = File.open(@outgoing_fifo_path, "w")
                puts "pipe opened"
                
              end
              
              message = @outgoing_port.pop # will block thread when Queue empty
              p message
              @f_w.puts message              
              @f_w.flush
              
              # puts "queue size: #{@outgoing_port.size}"
            rescue Errno::EPIPE => e
              puts "#{self.class}: outgoing pipe broken" 
              
              # NOTE: incoming port's queue will be cleared on restart
              
              # can't close the file here - will get an execption
              # but must open the FIFO again before writing
              
              # signal that FIFO should be reopened at the top of the loop
              @f_w = nil
            end
            
          end
        ensure
          # This outer ensure block is only for when thread exits.
          
          puts "#{self.class}: outgoing thread stopped"
          
          p @f_w
          p @outgoing_fifo_path
          
          # can't close if file handle was never set
          @f_w&.close
          
          # FIFO is always made even if not opened,
          # so always need to remove from the filesystem.
          FileUtils.rm(@outgoing_fifo_path)
            # can't use @f_w.path, because if no readers ever connect,
            # then the FIFO never opens,
            # and then @f_w == nil
          
          
          # @outgoing_status = :closed # NOTE(1): status set to closed here...
          puts "clear @outgoing_port"
          @outgoing_port.clear
          
          @f_w = nil # NOTE(3): setting the file handle to nil fixes the problem for now
          
          puts "outgoing fifo closed"
        end
        
        # NOTE: can use unix `cat` to monitor the output of this named pipe
        
      end
    end
    
    # blender has connected
    # resume sending data via the output port
    def reset
      # @outgoing_port.clear
      
      # @outgoing_status = :open # NOTE(2): ...but set to open here. thus, once the FIFO is closed, @outgoing_status will be :open when the new thread starts up, and the thread will not attempt to open it again.
      # Need to fundamentally fix the problem with this signalling structure in order to fix the bug. think about how the file is used, but also how the Queue is used to communicate with the rest of the system in the main thread. Perhaps we're conflating two different signals? Need to look into this.
      # p "status: #{@outgoing_status}"
    end
    
    
    
    
    # 
    # close communication channels
    # 
    
    def stop
      @incoming_thread.kill.join
      @outgoing_thread.kill.join
      
      # Release resources here instead of in ensure block on thread because the ensure block will not be called if the program crashes on first #setup. Likely this is because the program is terminating before the Thread has time to start up.
      
      p @f_r
      p @f_r.path
      
      @f_r.close
      FileUtils.rm(@f_r.path)
      puts "incoming fifo closed"
      
      
      
    end
    
    # 
    # communication is stopped if FIFOs do not exist on filesystem
    # 
    def stopped?
      return !File.exists?(@f_r.path)
    end
    
    
    # 
    # communicate via json messages
    # 
    
    # Send a message from ruby to python
    # (supress message if port is closed)
    def send(message)
      # if the port is open, queue the message (should go out soon)
      # if the port is closed, supress the message (don't even queue it up)
      
      
      # NOTE: can't use thread aliveness to figure out whether or not to queue messages. is there some other signal I can use? Ideally want to not to write to some variable in worker thread and main thread (thinking about future GIL-free parallelism - but maybe that's too far in the future?)
      
      # NOTE: current implementation doesn't crash, but doesn't clip the timeline range like hitting the blender button does. also requires manually turning the blender toggle back on.
        # can't reset the timeline on reset, because I can't send a loopback message to Blender
        # could possibly send a message when I figure out how to auto reconnect?
      
      # if @outgoing_thread.alive?
        @outgoing_port.push message.to_json
      # else
      #   # NO-OP
      # end
      
    end
    
    # Take the latest message from python to ruby out of the queue
    # (return nil if there are no messages in the queue)
    def take
      if @incoming_port.empty?
        return nil
      else
        # Queue#pop blocks the current thread while empty
        message_string = @incoming_port.pop
        message = JSON.parse message_string
        return message
      end
    end
    
    
    
    private
    
    
    def make_fifo(fifo_path)
      if fifo_path.exist?
        raise "ERROR: fifo (named pipe) already exists @ #{fifo_path}. Likely was not properly deleted on shutdown. Please manually delete the fifo file and try again."
      else
        File.mkfifo(fifo_path)
      end
      puts "fifo created @ #{fifo_path}"
      
      return fifo_path
    end
    
  end
  
end

