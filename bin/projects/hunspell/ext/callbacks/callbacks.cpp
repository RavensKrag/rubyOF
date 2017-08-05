#include "callbacks.h"

#include <iostream>

using namespace Rice;


// === define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}


#include <iostream>
#include <string>
#include <hunspell/hunspell.hxx>

// check the spelling of the supplied string using Hunspell
bool spell_check(std::string word) {
	// sources:
	// https://stackoverflow.com/questions/8326911/hunspell-any-solid-example
	// https://stackoverflow.com/questions/17241531/examples-tutorials-of-hunspell
	
	Hunspell hs ("/usr/share/hunspell/en_US.aff", "/usr/share/hunspell/en_US.dic");
	
	
	// NOTE: Ubuntu 16.04 uses Hunspell 1.4, which uses a rather old C-like API. The newer versions of Hunspell deal with std::string and like types.
	// sources:
	// https://github.com/hunspell/hunspell/blob/v1.4.0/src/tools/example.cxx
	// https://launchpad.net/ubuntu/+source/hunspell
	
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
}
