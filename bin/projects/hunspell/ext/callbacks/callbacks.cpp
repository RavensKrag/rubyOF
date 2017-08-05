#include "callbacks.h"

#include <iostream>

using namespace Rice;


// === define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}

// NOTE: DO NOT USE HUNSPELL THIS WAY. USE THE 'hunspell' RUBY GEM INSTEAD

// This project is kept here for exploratory reasons.
// Hopefully it will give some degree of insight
// into how to use Hunspell with C++.
// However, if you want to do spell checking in Ruby,
// it is better to use the 'hunspell' gem
// 
// (Do not use the 'ffi-hunspell' gem - that gem seems to
// have problems loading dictionaries. Doesn't give any errors,
// but I can't figure out how it works.)
// 
// While ffi-hunspell changes the API a bit in an attempt to be more Ruby-like
// (provides a convenient block for access)
// the 'hunspell' gem stays close to the original API (something I prefer)
// 

#include "SpellChecker.h"

// check the spelling of the supplied string using Hunspell
bool spell_check(std::string word) {
	
	
	// NOTE: Ubuntu 16.04 uses Hunspell 1.4, which uses a rather old C-like API. The newer versions of Hunspell deal with std::string and like types.
	// sources:
	// https://github.com/hunspell/hunspell/blob/v1.4.0/src/tools/example.cxx
	// https://launchpad.net/ubuntu/+source/hunspell
	
	
	Hunspell hs ("/usr/share/hunspell/en_US.aff", "/usr/share/hunspell/en_US.dic");
	
	char **slst = NULL;
	
	// parameter list
	// (1) out parameter ***slst (pointer to array of strings (char pointers))
	// (2) input parameter *word (the word you want suggestions for)
	// return: int - the number of strings in the newly allocated slst array.
	
	int n = 0;
	n = hs.suggest(&slst, word.c_str());
	
	for (int i = 0; i < n; i++) {
		std::cout << "    ..." << slst[i] << std::endl;
   }
	
	// use this to free the suggestion list
	if(n != 0){
		hs.free_list(&slst, n);
	}
	
	
	
	
	if(hs.spell(word.c_str()) == 0) {
		return false; // spelling error detected
	} else {
		return true;  // no errors
	}
}
// NOTE: Because this part is built separately, you could potentialy have some degree of dynamic reloading of C++ code if you wanted. Just reload this dynamic library.




// === "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
		.define_module_function("spell_check",   &spell_check)
	;
	
	
	// Have to wrap a custom class, because Rice only understands how to convert std::string, and not the char* argument that Hunspell takes
	// (Need Ruby::String to char* type converter)
	Data_Type<SpellChecker> rb_cHunspell =
		define_class_under<SpellChecker>(rb_mCallbacks, "Hunspell");
	
	rb_cHunspell
		.define_constructor(Constructor<SpellChecker, std::string, std::string>())
		
		.define_method("spell_check", &SpellChecker::spell_check)
		// .define_method("initialize", &Launcher::initialize)
		// .define_method("show",   &Launcher::show)
		// .define_method("ofExit", &ofExit,
		// 	(
		// 		Arg("status") = 0
		// 	)
		// )
		
		// .define_method("width",       &ofGetWidth)
		// .define_method("height",       &ofGetHeight)
	;
}
