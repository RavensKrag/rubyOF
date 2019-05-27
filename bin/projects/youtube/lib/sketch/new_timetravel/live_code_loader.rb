# generic Decorator pattern
  # Decorator in ruby: https://web.archive.org/web/20110223230202/https://lukeredpath.co.uk/blog/decorator-pattern-with-ruby-in-8-lines.html
# Extends any object type by composition, adding live coding functionality
class LiveCode
  # inner                : object to be wrapped
  # inner_class_filepath : file that defines inner.class 
  def initialize(inner, inner_class_filepath)
    @inner = inner
    @file = Pathname.new inner_class_filepath # handle Pathname and String
    
    @last_time = nil # set to nil so file is always reloaded the first time
    @state = :normal # [:normal, :error]
  end
  
  def method_missing(method, *args)
    args.empty? ? @inner.send(method) : @inner.send(method, args)
  end
  
  def update
    # Try to load the file once, and then update the timestamp
    # (prevents busted files every tick, which would flood the logs)
    
    begin
      if file_changed?
        # update the timestamp
        @last_time = Time.now
        
        # reload the file
        puts "live loading #{@file}"
        load @file.to_s
        
        puts "file loaded"
        @state = :normal
      end
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
      
      puts "FAILURE TO LOAD: #{@file}"
      $nonblocking_error.puts(e)
      
      @state = :error
      return false
    else
      # run if no exceptions
      case @state
        when :normal
          update_successful = @inner.update
          return update_successful
        when :error
          return false
        else
          msg = [
            "ERROR: unknown state encountered in live loader: #{@state}",
            "Expecting either :normal or :error."
          ].join("\n")
          raise msg
      end
    ensure
      # run whether or not there was an exception
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
  
end
