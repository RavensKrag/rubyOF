#include "SpellChecker.h"

// sources for Hunspell example code:
// https://stackoverflow.com/questions/8326911/hunspell-any-solid-example
// https://stackoverflow.com/questions/17241531/examples-tutorials-of-hunspell

using namespace Rice;

SpellChecker::SpellChecker
(const std::string & aff_path, const std::string & dic_path)
{
	mHS = new Hunspell(aff_path.c_str(), dic_path.c_str());
}

SpellChecker::~SpellChecker
()
{
	delete mHS;
}

// If the word is mispelled, return an ruby Array of suggested corrections.
// If the word is correctly spelled, return nil. 
Object
SpellChecker::spell_check
(std::string word)
{
	// NOTE: Ubuntu 16.04 uses Hunspell 1.4, which uses a rather old C-like API. The newer versions of Hunspell deal with std::string and like types.
	// sources:
	// https://github.com/hunspell/hunspell/blob/v1.4.0/src/tools/example.cxx
	// https://launchpad.net/ubuntu/+source/hunspell
	
	
	if(mHS->spell(word.c_str()) == 0) {
		// return false; // spelling error detected
		
		Array out;
		
		
		char **slst = NULL;
		
		// parameter list
		// (1) out parameter ***slst (pointer to array of strings (char pointers))
		// (2) input parameter *word (the word you want suggestions for)
		// return: int - the number of strings in the newly allocated slst array.
		
		int n = 0;
		n = mHS->suggest(&slst, word.c_str());
		
		for (int i = 0; i < n; i++) {
			std::cout << "    ..." << slst[i] << std::endl;
			
			std::string s = slst[i];
			out.push(s);
	   }
		
		// use this to free the suggestion list
		if(n != 0){
			mHS->free_list(&slst, n);
		}
		
		return out;
		
		
	} else {
		// return true;  // no errors
		
		
		return Rice::Nil;
	}
}
 
