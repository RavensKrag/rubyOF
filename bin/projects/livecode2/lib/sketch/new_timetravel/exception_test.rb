def protect_errors(&block)
  begin
    raise "BOOM!"
  rescue RuntimeError => e
    puts e.full_message # <= full error message
    # puts e # <= only a newline
    return false
  else
    # run if no exceptions
    return true
  ensure
    # run whether or not there was an exception
  end
end
