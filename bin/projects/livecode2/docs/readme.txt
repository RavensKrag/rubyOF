README

Some documentation to help explain now just what classes are, but how they fit togother




== groups of related files ==

1 - backbone of time traveling system
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



2 - control from both UI and REPL
---
pipeline.rb

window.rb #update --> @input_queue

UI_InputController.rb

update_fiber.rb
model_raw_input.rb      --> Model::RawInput
Core_InputController.rb --> Core_InputController

model_code.rb
model_main_code.rb
