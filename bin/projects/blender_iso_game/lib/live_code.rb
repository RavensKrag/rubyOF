# live loading environment
# (separate from Core to encapsulate certain variables)

# generic Decorator pattern
  # Decorator in ruby: https://web.archive.org/web/20110223230202/https://lukeredpath.co.uk/blog/decorator-pattern-with-ruby-in-8-lines.html
# Extends any object type by composition, adding live coding functionality
class LiveCode
  # inner     : object to be wrapped
  # watch_dir : directory where files to be reloaded are stored
  #             at minimum, one of these files should specify the inner object
  def initialize(inner, watch_dir)
    super()
    
    @inner = inner
    @watch_dir = Pathname.new watch_dir # handle Pathname and String
    
    @last_time = nil # set to nil so files are always reloaded the first time
  end
  
  # at minimum, the @inner object must respond to the following methods:
  #  @inner.setup()
  #  @inner.on_crash
  #  @inner.update(*args)
  #  @inner.on_reload
  # see core.rb for example
  
  
  state_machine :state, :initial => :normal do
    state :normal do
      
      def method_missing(method, *args)
        begin
          # puts "livecode - delegate: #{method}"
          return args.empty? ? @inner.send(method) : @inner.send(method, *args)
        rescue StandardError => e
          # puts "method missing error handler in LiveCode"
          puts "Error handler in LiveCode:"
          puts e.full_message.gsub GEM_ROOT.to_s, '[GEM_ROOT]'
          
          self.runtime_error_detected
          return nil
        end
      end
      
      def setup
        begin
          @inner.setup()
          @last_time = Time.now
        rescue StandardError => e
          @inner.on_crash
          raise e
        end
      end
      
      def update(*args)
        # Try to load the file once, and then update the timestamp
        # (prevents busted files every tick, which would flood the logs)
        
        
        # :reload_successful
        # :file_unchanged
        # :reload_failed
        signal = attempt_reload(first_time: @last_time.nil?)
        if signal == :reload_successful || signal == :file_unchanged
          begin
            update_signal = @inner.update(*args)
            return update_signal
          rescue StandardError => e
            puts "Error handler in LiveCode:"
            puts e.full_message.gsub GEM_ROOT.to_s, '[GEM_ROOT]'
            
            self.runtime_error_detected
            return :error
          end
        else # signal == :reload_failed
          return nil
        end
      end
        
    end
    
    
    # error detected. don't run any more until the file is updated.
    state :error do
      
      def method_missing(method, *args)
        # suspend delegation in order to suppress additional errors,
        # with the exception of certain key methods.
        
        allowed_methods = [
          :draw,    # time travel means a valid frame to draw is always loaded
                    # ^ maybe this isn't true? what about bugs in draw?
          :on_exit  # need to be able to shut down properly
        ]
        
        if allowed_methods.include? method
          # puts "livecode - delegate: #{method}"
          return args.empty? ? @inner.send(method) : @inner.send(method, *args)
        else
          
          # puts "livecode - supressing: #{method}"
        end
        
        # begin
        #   # puts "livecode - delegate: #{method}"
        #   return args.empty? ? @inner.send(method) : @inner.send(method, *args)
        # rescue StandardError => e
        #   # puts "method missing error handler in LiveCode"
        #   puts "Error handler in LiveCode:"
        #   puts e.full_message.gsub GEM_ROOT.to_s, '[GEM_ROOT]'
          
        #   self.runtime_error_detected
        #   return nil
        # end
      end
      
      def update(*args)
        @inner.update_while_crashed
        
        
        # :reload_successful
        # :file_unchanged
        # :reload_failed
        signal = attempt_reload(first_time: @last_time.nil?)
        if signal == :reload_successful || !@inner.in_error_state?
          self.error_patched
          
          begin
            update_signal = @inner.update(*args)
            return update_signal
          rescue StandardError => e
            puts "Error handler in LiveCode:"
            # puts "(error message supressed until later)"
            puts e.full_message
            
            self.runtime_error_detected
            return :error
          end
        else # signal == :reload_failed || signal == :file_unchanged
          return :error
        end
      end
      
    end
    
    
    event :load_error_detected do
      transition :normal => :error
    end
    
    event :runtime_error_detected do
      transition :normal => :error
    end
    
    event :error_patched do
      transition :error => :normal
    end
    
    
    
    # after_transition :on => :load_error_detected,    :do => :on_run
    after_transition :on => :runtime_error_detected, :do => :on_error_detected
    
    after_transition :on => :error_patched, :do => :on_error_patched
  end
  
  def on_error_detected
    puts "LiveCode: error detected"
    @inner.on_crash
  end
  
  def on_error_patched
    puts "LiveCode: error patched!"
  end
  
  
  
  
  
  def attempt_reload(first_time: true)
    return if first_time
    
    
    # select all files in the watch dir hierarchy that have changed
    files_to_update = 
      Dir[(@watch_dir + './**/*').expand_path]
      .collect{  |path_str|   Pathname.new(path_str) }
      .select{   |path|  path.mtime > @last_time }
    
    if files_to_update.size > 0
      # update the timestamp
      @last_time = Time.now
      
      # reload the files
      files_to_update.each do |file|
        begin
          puts "live loading #{file.to_s.gsub GEM_ROOT.to_s, '[GEM_ROOT]'}"
          load file.to_s
        rescue SyntaxError, ScriptError, NameError => e
          # This block triggers if there is some sort of
          # syntax error or similar - something that is
          # caught on load, rather than on run.
          
          # ----
          
          # NameError is a specific subclass of StandardError
          # other forms of StandardError should not happen on load.
          # 
          # If they are happening, something weird and unexpected has happened, and the program should fail spectacularly, as expected.
          
          # @on_error_callback.call(file, e)
          
          puts "FAILURE TO LOAD: #{file}"
          $nonblocking_error.puts(e)
          
          self.load_error_detected
          return :reload_failed
        else
          puts "file loaded"
        end
      end
      
      
      on_reload()
      return :reload_successful
    else
      return :file_unchanged
    end
  end
  
  
  
  
  def inner_class
    @inner.class
  end
  
  private
  
  def file_changed?
    # Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
      # It also has a constant called Rake::LATE, but I can't figure out how that works.
      # 
      # sources:
        # https://github.com/ruby/rake/blob/master/MIT-LICENSE
        # https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
    
    
    # Can't figure out how Rake::LATE works, but this works fine.
    
    @last_time.nil? or @file.mtime > @last_time
  end
  
  
  def on_reload
    @inner.on_reload
  end
  
end


