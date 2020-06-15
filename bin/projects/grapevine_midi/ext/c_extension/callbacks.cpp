#include "callbacks.h"

#include <iostream>
#include <Poco/Runnable.h>
#include <Poco/Thread.h>


using namespace Rice;


template<typename T>
struct Null_Free_Function
{
  static void free(T * obj) { }
};


// define your callbacks here
int cpp_callback(int x) {
	
	return 1;
}


// #define PROFILER_ENABLED true
// #define VALGRIND_ENABLED true



#include "spike_profiler.h"

#ifdef PROFILER_ENABLED
	#define PROFILER_FUNC()      ProfilerHelper __PVAR__ = ProfilerHelper(__func__, __FILE__, __LINE__)
	// __PVAR__ can be any symbol that won't ever be used by other code
#else
	#define PROFILER_FUNC()      
#endif


#include <valgrind/callgrind.h> 

#ifdef VALGRIND_ENABLED
	#define VALGRIND_ON      CALLGRIND_START_INSTRUMENTATION
	#define VALGRIND_OFF     CALLGRIND_STOP_INSTRUMENTATION
	// __PVAR__ can be any symbol that won't ever be used by other code
#else
	#define VALGRIND_ON      
	#define VALGRIND_OFF     
#endif







void render_material_editor(
	ofMesh & mesh, ofShader & shader, std::string & shader_filepath,
	ofTexture & tex0, ofTexture & tex1,
	int x, int y, int w, int h)
{
	stringstream textOut1, textOut2;
	
	textOut1 << "tex0 size: " << tex0.getWidth() << " x " << tex0.getHeight();
	textOut2 << "tex1 size: " << tex1.getWidth() << " x " << tex1.getHeight();
	
	shader.load(shader_filepath);
	shader.begin();
	
	shader.setUniformTexture("tex0", tex0, 0);
	shader.setUniformTexture("tex1", tex1, 1);
	
	
	ofPushMatrix();
		ofTranslate(x,y);
      ofScale(w,h);
		
		mesh.draw();
		
	ofPopMatrix();
	
	shader.end();
	
	
	ofPushStyle();
	
	ofColor text_color(0.0);
	
	ofSetColor(text_color);
	
	int bitmap_lineheight = 10;
	int offset = bitmap_lineheight;
	ofDrawBitmapString(textOut1.str(), x, y+offset+h+bitmap_lineheight*1);
	ofDrawBitmapString(textOut2.str(), x, y+offset+h+bitmap_lineheight*2);
	
	ofPopStyle();
}


// Rice can't convert std::string into std::filesystem::path, but they will convert. Thus, we use this helper function. Can establish automatic conversions in Rice, but only when both types are bound.
// 
// https://github.com/jasonroelofs/rice#implicit-casting-implicit_cast
// 
bool ofShader_loadShaders(ofShader & shader, Rice::Array args){
	if(args.size() == 1){
		Rice::Object x = args[0];
		std::string path = from_ruby<std::string>(x);
		return shader.load(path);
	}else if(args.size() == 2 || args.size() == 3){
		return false; // TODO: implement this form as well
	}
	
	return false;
}

// TODO: eventually want to bind uniforms through the ofShader member function, this is just a hold-over
void ofShader_bindUniforms(ofShader & shader, 
	std::string name1, float p1x, float p1y,
	std::string name2, float p2_1, float p2_2, float p2_3)
{
	shader.setUniform2f(name1, glm::vec2(p1x, p1y));
	shader.setUniform3f(name2, glm::vec3(p2_1, p2_2, p2_3));
}


// "header only" class style, at least for now
class ofxTerminalFont : public ofTrueTypeFont {
private:
	class MyWorker : public Poco::Runnable
	{
	public:
		MyWorker() : Poco::Runnable() {}
		
		void setup(ofxTerminalFont* font, ofMesh *mesh, std::string *str, int i)
		{
			this->font = font;
			this->i = i;
			this->mesh = mesh;
			this->str  = str;
			
			bFirstTime = true;
			mesh->clear();
		}
		
		virtual void run(){
			// cout << i << endl;
			
			font->meshify_line(mesh, str, i, bFirstTime);
			bFirstTime = false;
		}
		
	private:
		bool bFirstTime;
		
		ofxTerminalFont* font;
		ofMesh *mesh;
		std::string *str;
		int i;
		
	};
	
	
	
	size_t indexForGlyph_custom(uint32_t glyph) const{
		PROFILER_FUNC();
		
		return glyphIndexMap.find(glyph)->second;
	}
	
public:
	void drawChar_threadsafe(ofMesh &stringQuads, uint32_t c, float x, float y, bool vFlipped, int char_idx, bool bFirstTime) const{
		// PROFILER_FUNC();
		
		// if (!isValidGlyph(c)){ // <-- public member function
		// 	//ofLogError("ofTrueTypeFont") << "drawChar(): char " << c + NUM_CHARACTER_TO_START << " not allocated: line " << __LINE__ << " in " << __FILE__;
		// 	return;
		// }
		
		
		long xmin, ymin, xmax, ymax;
		float t1, v1, t2, v2;
		auto props = cps[indexForGlyph_custom(c)]; // <-- protected member function
		t1		= props.t1;
		t2		= props.t2;
		v2		= props.v2;
		v1		= props.v1;
		
		xmin		= long(props.xmin+x);
		ymin		= props.ymin;
		xmax		= long(props.xmax+x);
		ymax		= props.ymax;
		
		if(!vFlipped){
		   ymin *= -1;
		   ymax *= -1;
		}
		
		ymin += y;
		ymax += y;
		
		
		if(bFirstTime){
			ofIndexType firstIndex = stringQuads.getVertices().size();
			
			stringQuads.addVertex(glm::vec3(xmin,ymin,0.f));
			stringQuads.addVertex(glm::vec3(xmax,ymin,0.f));
			stringQuads.addVertex(glm::vec3(xmax,ymax,0.f));
			stringQuads.addVertex(glm::vec3(xmin,ymax,0.f));
			
			stringQuads.addTexCoord(glm::vec2(t1,v1));
			stringQuads.addTexCoord(glm::vec2(t2,v1));
			stringQuads.addTexCoord(glm::vec2(t2,v2));
			stringQuads.addTexCoord(glm::vec2(t1,v2));
			
			stringQuads.addIndex(firstIndex);
			stringQuads.addIndex(firstIndex+1);
			stringQuads.addIndex(firstIndex+2);
			stringQuads.addIndex(firstIndex+2);
			stringQuads.addIndex(firstIndex+3);
			stringQuads.addIndex(firstIndex);
		}
		else{
			stringQuads.setVertex(0+4*char_idx,glm::vec3(xmin,ymin,0.f));
			stringQuads.setVertex(1+4*char_idx,glm::vec3(xmax,ymin,0.f));
			stringQuads.setVertex(2+4*char_idx,glm::vec3(xmax,ymax,0.f));
			stringQuads.setVertex(3+4*char_idx,glm::vec3(xmin,ymax,0.f));
			
			stringQuads.setTexCoord(0+4*char_idx,glm::vec2(t1,v1));
			stringQuads.setTexCoord(1+4*char_idx,glm::vec2(t2,v1));
			stringQuads.setTexCoord(2+4*char_idx,glm::vec2(t2,v2));
			stringQuads.setTexCoord(3+4*char_idx,glm::vec2(t1,v2));
		}
	}
	
	
	void meshify_line(ofMesh *mesh, std::string *str, int i, bool bFirstTime)
	{
		PROFILER_FUNC();
		
		// size == number of lines to meshify
		// (should be size of both mesh_ary and str_ary)
		
		if(bFirstTime){
			mesh->clear();
		}
		
		// createStringMesh(c,x,y,vFlipped);
		bool vFlipped = true;
		float x, y;
		x = 0;
		y = 0;
		y += getLineHeight()*i;
		
		
		int directionX = settings.direction == OF_TTF_LEFT_TO_RIGHT?1:-1;
		
		// NOTES:
		// should be no newlines in this particular format, because we've split the "character grid" string on newline characters
		// I think I can commit to never using tabs
		// All characters should be valid unicode (can enforce at Ruby level if absolutely necessary) - thus, we don't really need to check again
		// Can assume the font is monospaced - thus we should either be able to compute the kerning once and just reuse it for the entire block of text, or the kerning should always be 0.	
			// kerning should be zero, according to this post: https://groups.google.com/forum/#!topic/comp.fonts/GyBrswH2N8k
				// John Hudson, Type Director
				// 
				// Tiro TypeWorks
				// Vancouver, BC
			// and nothing bad happens in the code when we take out kerning info!
		
		// optimizing under assumption of monospaced font
		// Therefore, only need to compute these three things once:
		long space__advance = getGlyphProperties(' ').advance;
		
		float space_inc  = space__advance * spaceSize * directionX;
		
		float letter_inc = (space__advance * directionX) + 
		                   (space__advance * (letterSpacing - 1.f) * directionX);
		
		// // ASSUME: spaces and letters both advance by the same increment
		// 	// for space:
		// 	x += space__advance * spaceSize * directionX;
			
		// 	// for non-space letters:
		// 	x += props.advance  * directionX;
		// 	x += space__advance * (letterSpacing - 1.f) * directionX;
		
		// TODO: optimize further by computing space_inc and letter_inc once when font size is specifyed (when the font is loaded)
		
		int char_idx = 0;
		for(auto c: ofUTF8Iterator((*str))){
			if(c == ' '){
				x += space_inc;
				
				drawChar_threadsafe((*mesh), c, x, y, vFlipped,
				                    char_idx, bFirstTime);
				
			}else{
				if(settings.direction == OF_TTF_LEFT_TO_RIGHT){
					drawChar_threadsafe((*mesh), c, x, y, vFlipped,
					                    char_idx, bFirstTime);
					
					x += letter_inc;
				}else{
					x += letter_inc;
					
					drawChar_threadsafe((*mesh), c, x, y, vFlipped,
					                    char_idx, bFirstTime);
				}
			}
			
			char_idx++;
		}
		
	}
	
	
	void meshify_lines(std::vector<ofMesh> *meshes,
	                   std::vector<std::string> *strings, bool bFirstTime)
	{
		PROFILER_FUNC();
		
		int size = strings->size();
		// cout << size << endl;
		
		// create threads
		// std::vector<MeshifyHelper*> threads;
		// threads.reserve(size);
		
		// // initialize workers
		// MyWorker workers[size];
		// for(int i=0; i<size; i++){
		// 	workers[i].setup(this, &(meshes->at(i)), &(strings->at(i)), i);
		// }
		
		// Poco::Thread threads[size];
		
		// // start up threads
		// for(int i=0; i<size; i++){
		// 	threads[i].start(workers[i]);
		// }
		
		// // wait for threads to complete
		// for(int i=0; i<size; i++){
		// 	threads[i].join();
		// }
		
		for(int i=0; i<size; i++){
			meshify_line(&(meshes->at(i)), &(strings->at(i)), i, bFirstTime);
		}
		
		
		// cout << "done!" << endl;
		
		// TODO: reduce number of threads to some small, fixed number based on the number of cores or similar. Then, distribute the work amongst those threads.
		
		// TODO: don't dynamically reallocate the meshes every time.
		// They're always going to have the same number of verts - just move the positions around
		
		
		
		// delete threads;
	}
	
	
};



// "header only" class style, at least for now
class CharMappedDisplay{
private:
	int _numCharsX, _numCharsY;
	bool _fgColorUpdateFlag = true;
	bool _bgColorUpdateFlag = true;
	
	// TODO: initialize some more c++ values here, instead of doing them elsewhere and passing them in via the Ruby layer
	
	ofPixels  _bgColorPixels;
	ofMesh    _bgMesh;        // likely the same across instances
	
	
	ofPixels  _fgColorPixels;
	ofTexture _fgColorTexture;
	ofShader  _fgColorShader; // should be the same across instances
	// NOTE: if you're creating multiple instances of this class, probably only need 1 mesh and 1 shader (singleton?)
	
	ofNode _bgNode;
	ofNode _fgNode;
	
	glm::vec2 _origin;
	
	ofxTerminalFont _font;
	
	std::vector<std::string> _strings;
	std::vector<ofMesh> _meshes;
	bool bFirstTime;
	
public:
	// CharMappedDisplay(){
		
	// }
	
	// ~CharMappedDisplay(){
		
	// }
	
	
	
	ofColor getColor_fg(int x, int y){
		return _fgColorPixels.getColor(x,y);
	}
	
	ofColor getColor_bg(int x, int y){
		return _bgColorPixels.getColor(x,y);
	}
	
	void setColor_fg(int x, int y, ofColor & c){	
		// set local color cache
		
		
		// (move colors from cache to pixels)
		// set pixel color
		_fgColorPixels.setColor(x,y, c);
		
		if(_fgColorUpdateFlag){
			// move pixel data to texture
			_fgColorTexture.loadData(_fgColorPixels, GL_RGBA);
		}
		// OPTIMIZE: similar to neopixel arduino code, can specify a bunch a pixel changes, and then push them to the GPU all at once
		
	}
	
	void setColor_bg(int x, int y, ofColor & c){
		_bgColorPixels.setColor(x,y, c);
		
		if(_bgColorUpdateFlag){
			// i = pos.x.to_i + pos.y.to_i*(@x_chars) # <-- ruby code
			int i = x + y*_numCharsX;
			// no need to add 1 here, because this only counts visible chars
			// and disregaurds the invisible newline at the end of each line
			
			_bgMesh.setColor(0+i*4, c);
			_bgMesh.setColor(1+i*4, c);
			_bgMesh.setColor(2+i*4, c);
			_bgMesh.setColor(3+i*4, c);
			
			// OPTIMIZE: consider using getColorsPointer() to set mulitple colors at once
			// https://openframeworks.cc/documentation/3d/ofMesh/#show_getColorsPointer
		}
	}
	
	
	int getNumCharsX(){
		return _numCharsX;
	}
	
	int getNumCharsY(){
		return _numCharsY;
	}
	
	
	
	
	
	
	void flushColors_bg(){
		for(int x=0; x < _numCharsX; x++){
			for(int y=0; y < _numCharsY; y++){
				ofColor c = _bgColorPixels.getColor(x,y);
				int i = x + y*_numCharsX;
				
				_bgMesh.setColor(0+i*4, c);
				_bgMesh.setColor(1+i*4, c);
				_bgMesh.setColor(2+i*4, c);
				_bgMesh.setColor(3+i*4, c);
			}
		}
	}
	
	void flushColors_fg(){
		_fgColorTexture.loadData(_fgColorPixels, GL_RGBA);
	}
	
	
	
	// the "autoUpdate" interface style taken
	// from arduino neopixel library by adafruit
	void autoUpdateColor_fg(bool flag){
		_fgColorUpdateFlag = flag;
	}
	
	void autoUpdateColor_bg(bool flag){
		_bgColorUpdateFlag = flag;
	}
	
	// flush colors to output
	void flush(){
		flushColors_bg();
		flushColors_fg();
	}
	
	
	
	
	void setup_transforms(float origin_x, float origin_y, 
	                      float offset_x, float offset_y,
	                      float scale_x,  float scale_y)
	{
		_bgNode.setPosition(origin_x+offset_x, origin_y+offset_y, 0);
		_bgNode.setScale(scale_x, scale_y, 1);
		
		
		_fgNode.setPosition(origin_x, origin_y, 0);
		
		_origin = glm::vec2(origin_x, origin_y);
	}
	
	void setup_font(ofTrueTypeFontSettings &settings){
		_font.load(settings);
	}
	
	
	void setup_text_grid(int w, int h){
		_strings.reserve(h);
		
		_meshes.reserve(h);
		for(int i=0; i<h; i++){
			_meshes.push_back(ofMesh());
		}
		
	}
	
	void cpp_remesh(Rice::Array lines){
		PROFILER_FUNC();
		VALGRIND_ON;
		
		
		_strings.clear();
		
		for(int i=0; i<lines.size(); i++)
		{
			Rice::Object str = lines[i];
			_strings.push_back(from_ruby<std::string>(str));
		}
		
		
		
		_font.meshify_lines(&_meshes, &_strings, bFirstTime);
		bFirstTime = false;
		
		VALGRIND_OFF;
	}
	
	
	void cpp_draw(){
		ofPushMatrix();
		
		// ofLoadIdentityMatrix();
		ofMultMatrix(_bgNode.getGlobalTransformMatrix());
		_bgMesh.draw();
		
		ofPopMatrix();
		
		
		
		ofPushMatrix();
		
		_fgColorShader.begin();
		
		_fgColorShader.setUniformTexture(
			"trueTypeTexture", _font.getFontTexture(),    0
		);
		_fgColorShader.setUniformTexture(
			"fontColorMap",    _fgColorTexture,           1
		);
		
		_fgColorShader.setUniform2f("origin", _origin);
		// _fgColorShader.setUniform3f("charSize", glm::vec3(p2_1, p2_2, p2_3));
		
		ofMultMatrix(_fgNode.getGlobalTransformMatrix());
		
		// text_mesh.draw();
		// TODO: iterate through meshes and draw them all
		for(int i=0; i < _meshes.size(); i++){
			_meshes[i].draw();
		}
		
		_fgColorShader.end();
		
		ofPopMatrix();
	}
	
	
	
	
	
	
	
	
	Rice::Data_Object<ofShader> fgText_getShader(){
		Rice::Data_Object<ofShader> rb_cPtr(
			&_fgColorShader,
			Rice::Data_Type< ofShader >::klass(),
			Rice::Default_Mark_Function< ofShader >::mark,
			Null_Free_Function< ofShader >::free
		);
		
		return rb_cPtr;
	}
	
	Rice::Data_Object<ofTexture> fgText_getTexture(){
		Rice::Data_Object<ofTexture> rb_cPtr(
			&_fgColorTexture,
			Rice::Data_Type< ofTexture >::klass(),
			Rice::Default_Mark_Function< ofTexture >::mark,
			Null_Free_Function< ofTexture >::free
		);
		
		return rb_cPtr;
	}
	
	Rice::Data_Object<ofPixels> getBgColorPixels(){
		Rice::Data_Object<ofPixels> rb_cPtr(
			&_bgColorPixels,
			Rice::Data_Type< ofPixels >::klass(),
			Rice::Default_Mark_Function< ofPixels >::mark,
			Null_Free_Function< ofPixels >::free
		);
		
		return rb_cPtr;
	}
	
	Rice::Data_Object<ofPixels> getFgColorPixels(){
		Rice::Data_Object<ofPixels> rb_cPtr(
			&_fgColorPixels,
			Rice::Data_Type< ofPixels >::klass(),
			Rice::Default_Mark_Function< ofPixels >::mark,
			Null_Free_Function< ofPixels >::free
		);
		
		return rb_cPtr;
	}
	
	
	Rice::Data_Object<ofTrueTypeFont> getFont(){
		Rice::Data_Object<ofTrueTypeFont> rb_cPtr(
			static_cast<ofTrueTypeFont*>(&_font),
			Rice::Data_Type< ofTrueTypeFont >::klass(),
			Rice::Default_Mark_Function< ofTrueTypeFont >::mark,
			Null_Free_Function< ofTrueTypeFont >::free
		);
		
		return rb_cPtr;
	}
	
	
	
	
	
	
	void bgMesh_draw(){
		_bgMesh.draw();
	}
	
	
	
	
	
	// create uniform mesh based on dimensions specified by Ruby code
	void bgMesh_setup(int w, int h){
		_bgMesh.setMode( OF_PRIMITIVE_TRIANGLES );
		
		for(int j=0; j < h; j++){
			for(int i=0; i < w; i++){
				
				_bgMesh.addVertex(glm::vec3((i+0), (j+0), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+0), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+0), (j+1), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+1), 0));
				_bgMesh.addColor(ofFloatColor(1,((float) i)/w,0));
				
				// ofColor will auto convert to ofFloatColor as necessary
				// https://forum.openframeworks.cc/t/relation-between-mesh-addvertex-and-addcolor/31314/3
				
				// need to replicate the verticies, because each vertex can only take one color
				
			}
		}
		
		for(int i=0; i < w*h; i++){
			_bgMesh.addIndex(2+i*4);
			_bgMesh.addIndex(1+i*4);
			_bgMesh.addIndex(0+i*4);
			
			_bgMesh.addIndex(2+i*4);
			_bgMesh.addIndex(3+i*4);
			_bgMesh.addIndex(1+i*4);
		}
	}
	
	
	void bgPixels_setup(int w, int h){
		// _fgColorPixels.clear(); // clear frees the color data - not needed
		
		// clear out the garbage
		for(int x=0; x<w; x++){
			for(int y=0; y<h; y++){
				ofColor c(100, 100, 100, 255);
				
				_fgColorPixels.setColor(x,y, c);
			}
		}
	}
	
	
	void fgPixels_setup(int w, int h){
		// _fgColorPixels.clear(); // clear frees the color data - not needed
		
		// clear out the garbage
		for(int x=0; x<w; x++){
			for(int y=0; y<h; y++){
				ofColor c(255, 255, 255, 255);
				
				_fgColorPixels.setColor(x,y, c);
			}
		}
		
		// set specific colors
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 255;
			c.b = 0;
			c.a = 255;
			
			_fgColorPixels.setColor(i,0, c);
		}
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 255;
			c.b = 255;
			c.a = 255;
			
			_fgColorPixels.setColor(i,1, c);
		}
		for(int i=0; i<30; i++){
			ofColor c;
			c.r = 0;
			c.g = 0;
			c.b = 255;
			c.a = 255;
			
			_fgColorPixels.setColor(i,2, c);
		}
		
		ofColor white(255, 255, 255,  255 );
		// illuminate 4 px in the top left
		_fgColorPixels.setColor(0,0, white);
		_fgColorPixels.setColor(0,1, white);
		_fgColorPixels.setColor(1,0, white);
		_fgColorPixels.setColor(1,1, white);
		// and light up the other 3 corners with 1 px each
		_fgColorPixels.setColor(0,h-1, white);
		_fgColorPixels.setColor(w-1,0, white);
		_fgColorPixels.setColor(w-1,h-1, white);
	}
	
	void setup_colors( int w, int h ){
		_numCharsX = w;
		_numCharsY = h;
		// int w = 60;
		// int h = 18;
		
		
		_bgColorPixels.allocate(_numCharsX,_numCharsY, OF_PIXELS_RGBA);
		_fgColorPixels.allocate(_numCharsX,_numCharsY, OF_PIXELS_RGBA);
		
		
		bgMesh_setup(_numCharsX,_numCharsY);
		
		bgPixels_setup(_numCharsX,_numCharsY);
		fgPixels_setup(_numCharsX,_numCharsY);
		
		flush();
		
		
		// _fgColorTexture.setTextureWrap(GL_REPEAT, GL_REPEAT);
		_fgColorTexture.setTextureMinMagFilter(GL_NEAREST, GL_NEAREST);
		
		bFirstTime = true;
	}
	
	
};


void callgrind_BEGIN(){
	CALLGRIND_START_INSTRUMENTATION;
}

void callgrind_END(){
	CALLGRIND_STOP_INSTRUMENTATION;
}

// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
		
		
		
		.define_module_function("render_material_editor", 
			                     &render_material_editor)
		
		
		.define_module_function("ofShader_loadShaders", 
			                     &ofShader_loadShaders)
		
		.define_module_function("ofShader_bindUniforms", 
			                     &ofShader_bindUniforms)
		
		
		.define_module_function("callgrind_BEGIN", &callgrind_BEGIN)
		.define_module_function("callgrind_END",   &callgrind_END)
	;
	
	
	
	
	
	Module rb_mProject = define_module_under(rb_mRubyOF, "Project");
	
	Data_Type<CharMappedDisplay> rb_c_ofCharMappedDisplay =
		define_class_under<CharMappedDisplay>(rb_mProject, "CharMappedDisplay");
	
	rb_c_ofCharMappedDisplay
		.define_constructor(Constructor<CharMappedDisplay>())
		
		.define_method("bgMesh_setup",     &CharMappedDisplay::bgMesh_setup)
		.define_method("bgPixels_setup",   &CharMappedDisplay::bgPixels_setup)
		.define_method("fgPixels_setup",   &CharMappedDisplay::fgPixels_setup)
		.define_method("setup_colors",     &CharMappedDisplay::setup_colors)
		
		.define_method("setup_transforms", &CharMappedDisplay::setup_transforms)
		.define_method("cpp_draw",         &CharMappedDisplay::cpp_draw)
		
		.define_method("setup_font",      &CharMappedDisplay::setup_font)
		.define_method("font",            &CharMappedDisplay::getFont)
		
		.define_method("setup_text_grid", &CharMappedDisplay::setup_text_grid)
		
		.define_method("cpp_remesh",      &CharMappedDisplay::cpp_remesh)
		
		.define_method("getColor_fg",    &CharMappedDisplay::getColor_fg)
		.define_method("getColor_bg",    &CharMappedDisplay::getColor_bg)
		.define_method("setColor_fg",    &CharMappedDisplay::setColor_fg)
		.define_method("setColor_bg",    &CharMappedDisplay::setColor_bg)
		
		.define_method("getNumCharsX",   &CharMappedDisplay::getNumCharsX)
		.define_method("getNumCharsY",   &CharMappedDisplay::getNumCharsY)
		
		
		.define_method("flushColors_bg", &CharMappedDisplay::flushColors_bg)
		.define_method("flushColors_fg", &CharMappedDisplay::flushColors_fg)
		.define_method("flush",
			&CharMappedDisplay::flush
		)
		.define_method("autoUpdateColor_fg", 
			&CharMappedDisplay::autoUpdateColor_fg
		)
		.define_method("autoUpdateColor_bg", 
			&CharMappedDisplay::autoUpdateColor_bg
		)
		
		.define_method("fgText_getShader",
			&CharMappedDisplay::fgText_getShader
		)
		.define_method("fgText_getTexture",
			&CharMappedDisplay::fgText_getTexture
		)
		
		.define_method("getBgColorPixels",
			&CharMappedDisplay::getBgColorPixels
		)
		.define_method("getFgColorPixels",
			&CharMappedDisplay::getFgColorPixels
		)
		
		
		.define_method("bgMesh_draw",
			&CharMappedDisplay::bgMesh_draw
		)
	;
	
	
	
	
	
	
	
	
	Module rb_mOFX = define_module_under(rb_mRubyOF, "OFX");
	
	Data_Type<ofxMidiOut> rb_c_ofxMidiOut =
		define_class_under<ofxMidiOut>(rb_mOFX, "MidiOut");
	
	rb_c_ofxMidiOut
		.define_constructor(Constructor<ofxMidiOut>())
		.define_method("sendNoteOn",   &ofxMidiOut::sendNoteOn)
		.define_method("sendNoteOff",  &ofxMidiOut::sendNoteOff)
		.define_method("listOutPorts", &ofxMidiOut::listOutPorts)
		
		// .define_method("openPort",     &ofxMidiOut::openPort)
		.define_method("openPort_uint",
			static_cast< bool (ofxMidiOut::*)
			(unsigned int portNumber)
			>(&ofxMidiOut::openPort)
		)
		.define_method("openPort_string",
			static_cast< bool (ofxMidiOut::*)
			(std::string deviceName)
			>(&ofxMidiOut::openPort)
		)
	;
	
	
	Data_Type<ofxMidiMessage> rb_c_ofxMidiMessage =
		define_class_under<ofxMidiMessage>(rb_mOFX, "MidiMessage");
	
	rb_c_ofxMidiMessage
		.define_constructor(Constructor<ofxMidiMessage>())
		
		.define_method("getStatus", &ofxMidiMessage__get_status)
		
		.define_method("channel",   &ofxMidiMessage__get_channel)
		.define_method("pitch",     &ofxMidiMessage__get_pitch)
		.define_method("velocity",  &ofxMidiMessage__get_velocity)
		.define_method("value",     &ofxMidiMessage__get_value)
		
		.define_method("deltatime", &ofxMidiMessage__get_deltatime)
		
		.define_method("portNum",   &ofxMidiMessage__get_portNum)
		.define_method("portName",  &ofxMidiMessage__get_portName)
		
		.define_method("get_num_bytes",  &ofxMidiMessage__get_num_bytes)
		.define_method("get_byte",       &ofxMidiMessage__get_byte)
	;
	
	
	// TODO: write glue code to access these fields:
	
	
	// ofxMidiOut midiOut
	
	
	
	
	// glm uses functions not methods
	// https://openframeworks.cc/documentation/glm/
	
	// can get members of vector either as x and y, or with array-style access
	
	Module rb_mGLM    = define_module("GLM");
	
	Data_Type<glm::tvec2<float>> rb_cVec2_float =
		define_class_under<glm::tvec2<float>>(rb_mGLM, "Vec2_float");
	
	rb_cVec2_float
		.define_method("get_component",   &glm_tvec2_float_get_component)
		.define_method("set_component",   &glm_tvec2_float_set_component)
	;
}


// 
// ext/openFrameworks/libs/glm/include/glm/detail/type_vec2.hpp
// 
float glm_tvec2_float_get_component(glm::tvec2<float>& p, int i){
	return p[i];
}

void  glm_tvec2_float_set_component(glm::tvec2<float>& p, int i, float value){
	p[i] = value;
}


// 
// ext/openFrameworks/addons/ofxMidi/src/ofxMidiMessage.h
// 

int ofxMidiMessage__get_status(ofxMidiMessage self){
	// do not need to explictly state array size
	// src: https://stackoverflow.com/questions/32918448/is-it-bad-to-not-define-a-static-array-size-in-a-class-but-rather-to-let-it-au
	static const MidiStatus STATUS_IDS[] = {
		MIDI_UNKNOWN,
		
		// channel voice messages
		MIDI_NOTE_OFF           ,
		MIDI_NOTE_ON            ,
		MIDI_CONTROL_CHANGE     ,
		MIDI_PROGRAM_CHANGE     ,
		MIDI_PITCH_BEND         ,
		MIDI_AFTERTOUCH         ,
		MIDI_POLY_AFTERTOUCH    ,
		
		// system messages
		MIDI_SYSEX              ,
		MIDI_TIME_CODE          ,
		MIDI_SONG_POS_POINTER   ,
		MIDI_SONG_SELECT        ,
		MIDI_TUNE_REQUEST       ,
		MIDI_SYSEX_END          ,
		MIDI_TIME_CLOCK         ,
		MIDI_START              ,
		MIDI_CONTINUE           ,
		MIDI_STOP               ,
		MIDI_ACTIVE_SENSING     ,
		MIDI_SYSTEM_RESET       
	};
	
	
	MidiStatus status = self.status;
	
	int ary_size = sizeof(STATUS_IDS)/sizeof(STATUS_IDS[0]);
	for(int i=0; i < ary_size; i++){
		if(status == STATUS_IDS[i]){
			return i;
		}
	}
	
	
	return -1; // return -1 on error
}

int ofxMidiMessage__get_channel(ofxMidiMessage self){
	return self.channel;
}
int ofxMidiMessage__get_pitch(ofxMidiMessage self){
	return self.pitch;
}
int ofxMidiMessage__get_velocity(ofxMidiMessage self){
	return self.velocity;
}
int ofxMidiMessage__get_value(ofxMidiMessage self){
	return self.value;
}

double ofxMidiMessage__get_deltatime(ofxMidiMessage self){
	return self.deltatime;
}

int ofxMidiMessage__get_portNum(ofxMidiMessage self){
	return self.portNum;
}
std::string ofxMidiMessage__get_portName(ofxMidiMessage self){
	return self.portName;
}


int ofxMidiMessage__get_num_bytes(ofxMidiMessage self){
	return self.bytes.size();
}

unsigned char ofxMidiMessage__get_byte(ofxMidiMessage self, int i){
	return self.bytes[i];
}
