require 'state_machine'

class Controller
  
  def initialize(input_history, ui_input, core_input, main_code, space)
    super()
    
    @timeline = Timeline.new(input_history, ui_input, core_input, main_code, space)
  end
  
  
  state_machine :time_travel_state, :initial => :main_timeline do
    state :main_timeline do
      
    end
    
    state :alternate_timeline do
      
    end
    # ----------
    
    event :change_the_past do
      # can splinter from the main timeline
      transition :main_timeline => :alternate_timeline
      
      # can splinter from one AU into another AU
      transition :alternate_timeline => :alternate_timeline
    end
    
    after_transition :on => :change_the_past, :do => :on_change_the_past
  end
  
  
  
  
  
  # dynamic reloading of code can possibly cause the creation of new, alternate timelines, depending on the current state of the controller
  def on_successful_reload
    if replaying?
      self.change_the_past
    end
  end
  
  def on_change_the_past
    # create new timeline
    # + duplicate history states into new objects
    # + point index to new history states
    # + change execution state to :running in order to generate new state
  end
  
  # "reading steiner" is a concept from steins;gate, a time-travel anime.
  # In the show, it means the ability to sense that the timeline has changed.
    # (Wait, that actually refers to change by d-mail. You don't move through time persay, but the world line moves around you. If you time leap / take a time machine back, and then cause a change - without incurring a time paradox - that's "opening steins;gate" [S01 E23, "Open the Steins Gate"])
    # wait no -- it's only opening steins gate when you cause a bifurcation in the system and enter a new attractor field. the only known mechanism for doing that is to decieve yourself and the world, changing events while maintaining the apperance of un-change. (krisu appears dead, but she is actually alive)

end

