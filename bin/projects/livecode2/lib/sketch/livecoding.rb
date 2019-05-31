# code reloader

require 'pathname'

# Need to rebind code, but keep data exactly the way it is in memory,
# because when I have a full history of states for Space I can roll
# back to, I don't want to have to pay the cost of full serialization
# every time I refresh the code.

# The idea is to dynamically reload the core part of the code base.
# From there, any reloading of additional types or data is
# 


class LiveCoding
  # NOTE: Save @inner, not the entire wrapper. This means you can move the defining code to some other location on disk if you would like, or between computers (system always uses absolute paths, so changing computer would break data, which is pretty bad)
  
  # remember file paths, and bind data
  def initialize(class_constant_name, header_path:, body_path:, save_file:)
    @header_code = header_path
    @body_code   = body_path
    @save_file = save_file
    
    
    @last_load_time = Time.now
    
    dynamic_load @header_code # defines #initialize and #dump
    dynamic_load @body_code   # defines all other methods
    
    @klass = Kernel.constant_get(class_constant_name)
    
    @inner = 
      if @save_file.exist?
        # load data
        YAML.load_file(@save_file)
      else
        # create new data
        @klass.new(@save_file) 
      end
    
  end
  
  # automatically save data to disk before exiting
  def on_exit
    # save world state to file
    File.open @save_file, 'w' do |f|
      YAML.dump(@inner, f) 
    end
  end
  
  
  # reload code as needed
  def update
    # if @body_code file is newer than @last_load_time
    if file_changed?(@body_code, last_time)
      dynamic_load @body_code
      @last_load_time = Time.now
    end
    
    runtime_guard do
      @inner.update
    end
  end
  
  
  # NOTE: under this architecture, you can't dynamically change initialization or serialization code - you would have to restart the program if that sort of change is made
  # ^ is this still true?
  
  
  
  
  
  private
  
  
  
  def file_changed?(file, last_time)
    # Rake uses File.mtime(path_to_file) to figure out if files are out of date or not. 
      # It also has a constant called Rake::LATE, but I can't figure out how that works.
      # 
      # sources:
        # https://github.com/ruby/rake/blob/master/MIT-LICENSE
        # https://github.com/ruby/rake/blob/master/lib/rake/file_task.rb
    
    
    # Can't figure out how Rake::LATE works, but this works fine.
    
    last_time.nil? or file.mtime > last_time
  end
  
  
  # If you encounter a runtime error with live coded code,
  # the greater program will continue to run.
  # (centralizing error code from #update and #setup_delegators)
  def runtime_guard # &block
    begin
      yield
    rescue StandardError => e
      # keep execption from halting program,
      # but still output the exception's information.
      livecode_error_handler(e)
      
      unload(kill:true)
      # ^ stop further execution of the bound @inner
    end
  end
  
  def dynamic_load(file)
    begin
      load file
    rescue ScriptError, NameError => e
      # This block triggers if there is some sort of
      # syntax error or similar - something that is
      # caught on load, rather than on run.
      
      # ----
      
      # NameError is a specific subclass of StandardError
      # other forms of StandardError should not happen on load.
      # 
      # If they are happening, something weird and unexpected has happened, and the program should fail spectacularly, as expected.
      
      # load failed.
      # corresponding snippets have already been deactivated.
      # only need to display the errors
      
      puts "FAILURE TO LOAD: #{file}"
      
      livecode_error_handler(e)
    end
  end
  
  
  
  # error handling helper
  def livecode_error_handler(e)
    puts "KABOOM!"
    
    # everything below this point deals only with the execption object 'e'
    
    
    # FACT: Proc with instance_eval makes the resoultion of e.message very slow (20 s)
    # FACT: Using class-based snippets makes resolution of e.message quite fast (10 ms)
    # ASSUME: Proc takes longer to resolve because it has to look in the symbol table of another object (the Window)
    # --------------
    # CONCLUSION: Much better for performance to use class-based snippets.
    
    Thread.new do
      # NOTE: Can only call a fiber within the same thread.
      
      t1 = RubyOF::Utils.ofGetElapsedTimeMillis
      
      out = [
        # e.class, # using this instead of "message"
        # e.name, # for NameError
        # e.local_variables.inspect,
        # e.receiver, # this might actually be the slow bit?
        e.message, # message is the "rate limiting step"
        e.backtrace
      ]
      
      # p out
      puts out.join("\n")
      
      
      t3 = RubyOF::Utils.ofGetElapsedTimeMillis
      dt = t3 - t1
      puts "Final dt: #{dt} ms"
      puts ""
    end
    
  end
  
  
  
  
  # Deactivate an active instance of a Snippet
  # (only save data when you have a reasonable guarantee it will be safe)
  # (better to roll back a little, than to save bad data)
  def unload(kill:false)
    puts "Unloading: #{@klass}"
    
    unless @inner.nil?
      @inner.on_exit()
      
      if kill
        # (kill now: dont save data, as it may be corrupted)
        
      else
        # (safe shutdown: save data before unloading)
        
        # save world state to file
        File.open @save_file, 'w' do |f|
          YAML.dump(@inner, f) 
        end
      end
      
      @inner = nil
    end
  end
  
  
end


class Window
  def initialize
    @save_path = Pathname.new("bin/data.yml").expand_path
    
    # path.exist?
    # path.file?
    # path.directory?
    
    # 2.5.1 :014 > file.methods.grep /tim/
    #  => [:atime, :mtime, :ctime, :birthtime, :utime] 
    
    # load world state from file, or create new state
    @live = LiveCoding.new(
              "InnerClass",
              header: "path/to/code/head.rb",
              body:   "path/to/code/main.rb",
              save_file: "bin/data.yml"
            )
    
    # NOTE: need to force reload if initializer or name of wrapper class has changed since the save file was created
    
    
  end
  
  def on_exit
    puts "shutting down..."
    
    @live.on_exit
    
    puts "DONE"
  end
  
  def update
    @live.update
    
    
    # if you call #update on the @inner object directly like this, you can't guard for execeptions. this means that any exception that fires will bring down the whole program, all the way down to the c++ level.
    @live.inner.update
  end
  
  def draw
    @live.inner.draw
  end
end

