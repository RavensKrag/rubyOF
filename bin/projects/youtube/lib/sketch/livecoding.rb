# code reloader

require 'pathname'

class LiveCoding
  attr_reader :inner
  
  # remember file paths, and bind data
  def initialize(class_constant_name, header_path:, body_path:)
    @header_code = header_path
    @body_code   = body_path
    
    
    @last_load_time = Time.now
    
    load @header_code # defines #initialize and #dump
    load @body_code   # defines all other methods
    
    @klass = Kernel.constant_get(class_constant_name)
    
    @inner = @klass.new(@world_state_path) # load data
  end
  
  # automatically save data to disk before exiting
  def on_exit
    @inner.dump(@world_state_path) # dump data
  end
  
  
  # reload code as needed
  def update
    # if @body_code file is newer than @last_load_time
    if file_changed?(@body_code, last_time)
      load @body_code
      @last_load_time = Time.now
    end
    
    
    @inner.update
  end
  
  
  # NOTE: under this architecture, you can't dynamically change initialization or serialization code - you would have to restart the program if that sort of change is made
  
  
  
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
  def protect_runtime_errors # &block
    begin
      yield
    rescue StandardError => e
      # keep execption from halting program,
      # but still output the exception's information.
      process_snippet_error(e)
      
      unload(kill:true)
      # ^ stop further execution of the bound @wrapped_object
    end
  end
  
  
  # Deactivate an active instance of a Snippet
  # (only save data when you have a reasonable guarantee it will be safe)
  # (better to roll back a little, than to save bad data)
  def unload(kill:false)
    puts "Unloading: #{@klass}"
    
    unless @inner.nil?
      @inner.cleanup()
      if kill
        # (kill now: dont save data, as it may be corrupted)
        
      else
        # (safe shutdown: save data before unloading)
        @inner.serialize(@save_directory)
      end
      
      @inner =  nil
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
    @live = 
      if @save_path.exist?
        YAML.load_file("bin/data.yml")
      else
        # NOTE: need to force reload if initializer or name of wrapper class has changed since the save file was created
        LiveCoding.new(
          "InnerClass",
          header: "path/to/code/head.rb",
          body:   "path/to/code/main.rb"
        )
      end
    
    
  end
  
  def on_exit
    puts "shutting down..."
    
    # save world state to file
    File.open @save_path, 'w' do |f|
      YAML.dump(@live, f) 
    end
    
    puts "DONE"
  end
  
  def update
    @live.update
    
    @live.inner.update
  end
  
  def draw
    @live.inner.draw
  end
end

