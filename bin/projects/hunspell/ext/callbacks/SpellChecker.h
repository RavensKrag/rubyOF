#include <iostream>
#include <string>
#include <hunspell/hunspell.hxx>

#include "rice/Data_Type.hpp"
#include "rice/Constructor.hpp"
#include "rice/Class.hpp"
#include "rice/Module.hpp"

#include "rice/Array.hpp"


class SpellChecker {
	public: 
		SpellChecker(const std::string & aff_path, const std::string & dic_path);
		~SpellChecker();
		
		Rice::Object spell_check(std::string word);
	
	
	private:
		Hunspell* mHS;
	// protected:
};
