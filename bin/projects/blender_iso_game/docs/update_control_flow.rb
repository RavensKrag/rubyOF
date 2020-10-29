# === update ===

# UI inputs control position in timeline
# back / forward / pause / play
input_queue -> @ui_input
# Array        LiveCode
#                UI_InputController


# REPL      -> @timeline_controller
# @ui_input -> @timeline_controller
@timeline_controller
  
  # -- input
  input_queue -> @input_history -> @core_input
  # Array        History           LiveCode
  #                LiveCode          Core_InputController     
  # 
  
  
  # -- code
  @main_code
  # History
  #   LiveCode
  #     MainCode
  
  
  # -- space
  @core_space
  # History
  #   Model::CoreSpace

  
# -- visualization
@main_view
# ==========




# === draw ===
@main_view

# ==========


# NOTE: must update space after main code, otherwise changes to space made by main code will not be saved until the next frame.

# NOTE: when code reaches the end of execution, do not save any more history, but continue to advance the @i in controller. need to continue to take in input events.

# FIXME: History#update tries to act on nil sometimes
  # + run to end of main code executino
  # + continue running to gather more input data
  # + pause
  # + take a couple steps back
  # + step forward
  # (at this point, system will re-load state from History)
  # (system loads a nil, after accessing a main code state past end of array)
  # => History#update tries to act on nil and crashes
