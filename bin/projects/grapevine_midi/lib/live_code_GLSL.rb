# live loading environment for GLSL shaders


# generic Decorator pattern
  # Decorator in ruby: https://web.archive.org/web/20110223230202/https://lukeredpath.co.uk/blog/decorator-pattern-with-ruby-in-8-lines.html
# Extends any object type by composition, adding live coding functionality
class LiveCode_GLSL
  # inner                : object to be wrapped
  # inner_class_filepath : file that defines inner.class 
  def initialize(shader_filepath, &block)
    super()
    
    @callback = block
    @file = Pathname.new shader_filepath # handle Pathname and String
    
      @file = Pathname.new shader_filepath # handle Pathname and String
      
      @files = [
        @file.to_s + '.vert',
        @file.to_s + '.frag'
      ]
      
    @last_time = nil # set to nil so file is always reloaded the first time
  end
  
  
  state_machine :state, :initial => :normal do
    state :normal do
      
      def update(*args)
        # Try to load the file once, and then update the timestamp
        # (prevents busted files every tick, which would flood the logs)
        
        
        # :reload_successful
        # :file_unchanged
        # :reload_failed
        signal = attempt_reload()
        if signal == :reload_successful || signal == :file_unchanged
          
        else # signal == :reload_failed
          return nil
        end
      end
        
    end
    
    
    # error detected. don't run any more until the file is updated.
    state :error do
      
      def update(*args)
        # :reload_successful
        # :file_unchanged
        # :reload_failed
        signal = attempt_reload()
        if signal == :reload_successful
          self.error_patched
        else # signal == :reload_failed || signal == :file_unchanged
          return :error
        end
      end
      
    end
    
    
    event :load_error_detected do
      transition :normal => :error
    end
    
    event :error_patched do
      transition :error => :normal
    end
    
    
    
    after_transition :on => :load_error_detected, :do => ->(){
      puts "LiveCode GLSL: couldn't load shaders"
    }
    after_transition :on => :error_patched, :do => ->(){
      puts "LiveCode GLSL: error patched!"
    }
  end
  
  
  
  private
  
  
  def attempt_reload
    if @files.any?{|f| file_changed?(f) }
      # update the timestamp
      @last_time = Time.now
      
      # reload the file
      puts "live loading #{@file.to_s.gsub GEM_ROOT.to_s, '[GEM_ROOT]'}"
      
      load_flag = @glsl_load_callback.call
      
      if load_flag
        puts "file loaded"
        
        # on_reload()
        return :reload_successful
        
      else
        # Some sort of GLSL syntax error has occurred.
        # Should print the error message once, and then
        # transition to error state
        # 
        
        
        # This block triggers if there is some sort of
        # syntax error or similar - something that is
        # caught on load, rather than on run.
        
        # ----
        
        # @on_error_callback.call(file, e)
        
        puts "FAILURE TO LOAD: #{@file}"
        $nonblocking_error.puts(e)
        
        self.load_error_detected
        return :reload_failed
        
      end
      
    else
      return :file_unchanged
    end
  end
  
  
  def file_changed?(file)
    # Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
      # It also has a constant called Rake::LATE, but I can't figure out how that works.
      # 
      # sources:
        # https://github.com/ruby/rake/blob/master/MIT-LICENSE
        # https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
    
    
    # Can't figure out how Rake::LATE works, but this works fine.
    
    @last_time.nil? or file.mtime > @last_time
  end
end


