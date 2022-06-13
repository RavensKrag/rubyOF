#include "wrap_ofxAlembic.h"

#include "Null_Free_Function.h"

using namespace Rice;

void wrap_ofxAlembic(Module rb_mOFX){
	Module rb_mOFX_Alembic = define_module_under(rb_mOFX, "Alembic");
	
	
	
	Data_Type<ofxAlembic::IGeom> rb_c_ofxAlembic_IGeom =
		define_class_under<ofxAlembic::IGeom>(rb_mOFX_Alembic, "IGeom");
	
	rb_c_ofxAlembic_IGeom
		.define_constructor(Constructor<ofxAlembic::IGeom>())
		
		.define_method("transform",  &ofxAlembic::IGeom::getGlobalTransform)
		// .define_method("index",      &ofxAlembic::IGeom::getIndex)
			// ^ index does not behave as expected, so just don't use it.
		.define_method("name",       &ofxAlembic__IGeom__getName)
		.define_method("full_name",  &ofxAlembic::IGeom::getFullName)
		.define_method("type_name",  &ofxAlembic::IGeom::getTypeName)
		
		// .define_method("get",  &ofxAlembic::IGeom::get)
		// // ^ this is overloaded
		
		
		.define_method("get_mat4",  &ofxAlembic__IGeom__getMat4)
		.define_method("get_mesh",  &ofxAlembic__IGeom__getMesh)
		.define_method("get_faceset",  &ofxAlembic__IGeom__getFaceSet)
	;
	
	
	Data_Type<ofxAlembic::Reader> rb_c_ofxAlembic_Reader =
		define_class_under<ofxAlembic::Reader>(rb_mOFX_Alembic, "Reader");
	
	rb_c_ofxAlembic_Reader
		.define_constructor(Constructor<ofxAlembic::Reader>())
		
		.define_method("open",   &ofxAlembic::Reader::open)
		.define_method("close",  &ofxAlembic::Reader::close)
		
		// .define_method("get",    &ofxAlembic::Reader::get)
		// // ^ this is overloaded
		
		.define_method("time=",  &ofxAlembic::Reader::setTime)
		.define_method("time",   &ofxAlembic::Reader::getTime)
		
		.define_method("size",       &ofxAlembic::Reader::size)
		.define_method("names",      &ofxAlembic__Reader__getNames)
		.define_method("fullnames",  &ofxAlembic__Reader__getFullnames)
		
		.define_method("dump_names",     &ofxAlembic::Reader::dumpNames)
		.define_method("dump_fullnames", &ofxAlembic::Reader::dumpFullnames)
		
		
		.define_method("get_node",  &ofxAlembic__Reader__getNode)
		
		
		// .define_method("each",  &ofxAlembic__Reader__each)
		
		
		// .define_method("get_mesh",  &ofxAlembic__Reader__getFullnames)
		// .define_method("get_mesh",  &ofxAlembic__Reader__getFullnames)
		// .define_method("get_mesh",  &ofxAlembic__Reader__getFullnames)
		
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


Rice::Data_Object<ofxAlembic::IGeom>
ofxAlembic__Reader__getNode(ofxAlembic::Reader& reader, const string& path){
	
	auto ptr = reader.get(path);
	
	Rice::Data_Object<ofxAlembic::IGeom> rb_cPtr(
		ptr,
		Rice::Data_Type< ofxAlembic::IGeom >::klass(),
		Rice::Default_Mark_Function< ofxAlembic::IGeom >::mark,
		Null_Free_Function< ofxAlembic::IGeom >::free
	);
	
	return rb_cPtr;
}

// Need to force string copy to prevent segfault. may be able to do this better in the new version of Rice, which handles memory ownership differently. But not right now.
std::string
ofxAlembic__IGeom__getName(ofxAlembic::IGeom& node){
	std::string str_out;
	
	str_out = node.getName(); // force copy
	
	return str_out; // return the copy
}


// ofMatrix4v4 can be convert to mat4, but they are not binary equivalents
void
ofxAlembic__IGeom__getMat4(ofxAlembic::IGeom& n, glm::mat4 &mat){
	ofMatrix4x4 ofmat;
	n.get(ofmat);
	
	mat = ofmat;
}

void
ofxAlembic__IGeom__getMesh(ofxAlembic::IGeom& n, ofMesh &mesh){
	n.get(mesh);
}

void
ofxAlembic__IGeom__getFaceSet(ofxAlembic::IGeom& n, ofxAlembic::FaceSet &faces){
	n.get(faces);
}
