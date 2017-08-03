#include "callbacks.h"

#include <iostream>

using namespace Rice;


// define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}


// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
	;
}
