
# input handler will supress OS-level key repeat events
class InputHandler
  def initialize
    @buttons = Hash.new
    @callbacks = Hash.new
  end
  
  def register_callback(btn, &block)
    @buttons[btn] = false
    
    helper = InputHandlerHelper.new
    block.call(helper)
    @callbacks[btn] = helper
  end
  
  # 4 states
  # ----
  # idle
  # positive edge
  # active
  # negative edge
  
  def update
    @callbacks.each do |btn, callback_obj|
      current_state = @buttons[btn]
      
      # p callback_obj
      
      # require 'irb'
      # binding.irb
      
      if current_state
        # hi = active
        callback_obj.while_active_call()
      else
        # low = idle
        callback_obj.while_idle_call()
      end
    end
  end
  
  def key_pressed(id)
    if id == OF_KEY_ESC
      return
      # bypass this whole thing when the escape key is pressed
      # (escape quits the app)
    end
    if @buttons[id].nil?
      warn "ERROR: no callbacks registered for button id: #{id}"
      return
    end
    
    current_state = @buttons[id]
    
    if current_state
      # hi -> hi
      # NO-OP
    else
      # low -> hi
      # positive edge
      callback_obj = @callbacks[id]
      callback_obj.on_press_call()
    end
        
    
    @buttons[id] = true
  end
  
  def key_released(id)
    if id == OF_KEY_ESC
      return
      # bypass this whole thing when the escape key is pressed
      # (escape quits the app)
    end
    if @buttons[id].nil?
      warn "ERROR: no callbacks registered for button id: #{id}"
      return
    end
    
    
    current_state = @buttons[id]
    
    if current_state
      # hi -> low
      callback_obj = @callbacks[id]
      callback_obj.on_release_call()
    else
      # low -> low
      # NO-OP
    end
    
    @buttons[id] = false
  end
  
  private
  
  
  class InputHandlerHelper
    def on_press(&block)
      @on_press = block
    end
    
    def on_release(&block)
      @on_release = block
    end
    
    def while_idle(&block)
      puts "idle callback set"
      @while_idle = block
    end
    
    def while_active(&block)
      @while_active = block
    end
    
    [:on_press, :on_release, :while_idle, :while_active].each do |sym|
      define_method "#{sym}_call" do |*args|
        instance_variable_get("@#{sym}").call(*args)
      end
    end
  end
end
