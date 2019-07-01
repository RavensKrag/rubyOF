README

Some documentation to help explain now just what classes are, but how they fit togother




== groups of related files ==

001 - baseline (main and window)
---
.gitignore
button_event_codes.rb
window.rb - lib/rubyOF
window_guard.rb
main.rb - bin
main.rb bin/../lib
app.h
app.cpp


005 - backbone of time traveling system
---
history.rb

live_code_loader.rb
	update_fiber.rb
	nonblocking_error_output.rb


model_code.rb
model_main_code.rb
model_raw_input.rb

controller_state_machine.rb

view_visualize_controller.rb



006 - control from both UI and REPL
---
pipeline.rb

window.rb #update --> @input_queue

UI_InputController.rb

update_fiber.rb
model_raw_input.rb      --> Model::RawInput
Core_InputController.rb --> Core_InputController

model_code.rb
model_main_code.rb
