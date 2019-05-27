# generic Decorator pattern
  # Decorator in ruby: https://web.archive.org/web/20110223230202/https://lukeredpath.co.uk/blog/decorator-pattern-with-ruby-in-8-lines.html
# Extends any object type by composition, adding live coding functionality
class LiveCode
  # inner                : object to be wrapped
  # inner_class_filepath : file that defines inner.class 
  def initialize(inner, inner_class_filepath, on_load_attempt:, on_load:, on_error:)
    @inner = inner
    @filepath = Pathname.new inner_class_filepath # handle Pathname and String
    
    @on_load_attempt_callback = 
    @on_load_callback = on_load
    @on_error_callback = on_error
    
    @last_time = nil # set to nil so file is always reloaded the first time
  end
  
  def method_missing(method, *args)
    args.empty? ? @inner.send(method) : @inner.send(method, args)
  end
  
  def update
    reload_file if file_changed?
    
    @inner.update
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
  
  # Try to load the file once, and then update the timestamp
  # (prevents busted files every tick, which would flood the logs)
  def reload_file
    # update the timestamp
    @last_time = Time.now
    
    begin
      # reload the file
      @on_load_attempt_callback.call(@filepath)
      load @filepath.to_s
    rescue SyntaxError, ScriptError, NameError => e
      # This block triggers if there is some sort of
      # syntax error or similar - something that is
      # caught on load, rather than on run.
      
      # ----
      
      # NameError is a specific subclass of StandardError
      # other forms of StandardError should not happen on load.
      # 
      # If they are happening, something weird and unexpected has happened, and the program should fail spectacularly, as expected.
      
      @on_error_callback.call(file, e)
    else
      # run if no exceptions
      @on_load_callback.call(@filepath)
    ensure
      # run whether or not there was an exception
    end
  end
end
