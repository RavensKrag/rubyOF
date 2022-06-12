#include "wrap_ofxAlembic.h"

using namespace Rice;

void wrap_ofxAlembic(Module rb_mOFX){
	Module rb_mOFX_Alembic = define_module_under(rb_mOFX, "Alembic");
	
	
	Data_Type<ofxAlembic::Reader> rb_c_ofxAlembic_Reader =
		define_class_under<ofxAlembic::Reader>(rb_mOFX_Alembic, "Reader");
	
	rb_c_ofxAlembic_Reader
		.define_constructor(Constructor<ofxAlembic::Reader>())
		.define_method("open",   &ofxAlembic::Reader::open)
		.define_method("close",  &ofxAlembic::Reader::close)
		
		.define_method("time=",  &ofxAlembic::Reader::setTime)
		.define_method("time",   &ofxAlembic::Reader::getTime)
		
		.define_method("size",       &ofxAlembic::Reader::size)
		.define_method("names",      &ofxAlembic__Reader__getNames)
		.define_method("fullnames",  &ofxAlembic__Reader__getFullnames)
		
		// .define_method("listOutPorts", &ofxMidiOut::listOutPorts)
		
		// // .define_method("openPort",     &ofxMidiOut::openPort)
		// .define_method("openPort_uint",
		// 	static_cast< bool (ofxMidiOut::*)
		// 	(unsigned int portNumber)
		// 	>(&ofxMidiOut::openPort)
		// )
		// .define_method("openPort_string",
		// 	static_cast< bool (ofxMidiOut::*)
		// 	(std::string deviceName)
		// 	>(&ofxMidiOut::openPort)
		// )
	;
	
}


Rice::Array ofxAlembic__Reader__getNames(ofxAlembic::Reader& reader){
	vector<string> names = reader.getNames();
	
	Rice::Array filepaths;
	
	for(int i=0; i < names.size(); i++) {
		std::string &s = names[i];
		filepaths.push(to_ruby(s));
	}
	
	return filepaths;
}

Rice::Array ofxAlembic__Reader__getFullnames(ofxAlembic::Reader& reader){
	vector<string> names = reader.getFullnames();
	
	Rice::Array filepaths;
	
	for(int i=0; i < names.size(); i++) {
		std::string &s = names[i];
		filepaths.push(to_ruby(s));
	}
	
	return filepaths;
}
