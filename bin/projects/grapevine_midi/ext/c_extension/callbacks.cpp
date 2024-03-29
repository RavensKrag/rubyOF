#include "callbacks.h"

#include <iostream>
#include <Poco/Runnable.h>
#include <Poco/Thread.h>

#include "Null_Free_Function.h"

using namespace Rice;

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
	size_t indexForGlyph_custom(uint32_t glyph) const{
		// PROFILER_FUNC();
		
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
	
	
	void meshify_line(ofMesh *mesh, uint32_t *line, int line_len, int i, bool bFirstTime)
	{
		PROFILER_FUNC();
		
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
		
		for(int char_idx=0; char_idx < line_len; char_idx++){
			uint32_t c = line[char_idx];
			
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
		}
		
	}
	
};


class ImageFiller{
private:
	ofPixels *_pixels;

public:
	// ImageFiller();
	// ~ImageFiller();
	
	
	// this function is for C++ level code only
	void setup(ofPixels *pixels){
		_pixels = pixels;
	}
	
	void fill_all(ofColor &color){
		_pixels->setColor(color);
	}
	
	
	void fill_bb(int l, int b, int r, int t, ofColor &color){
		for(int i=l; i<r+1; i++){
			for(int j=b; j<t+1; j++){
				_pixels->setColor(i,j, color);
			}
		}
	}
	
	void fill_row(int y, ofColor &color){
		for(int i=0; i<_pixels->getWidth(); i++){
			_pixels->setColor(i,y, color);
		}
	}
	
	void fill_column(int x, ofColor &color){
		for(int i=0; i<_pixels->getHeight(); i++){
			_pixels->setColor(x,i, color);
		}
	}
	
	void fill_point(int x, int y, ofColor &color){
		_pixels->setColor(x,y, color);
	}
	
	ofColor getColor(int x, int y){
		return _pixels->getColor(x,y);
	}
};

// "header only" class style, at least for now
class CharMappedDisplay{
private:
	int _numCharsX, _numCharsY;
	
	// TODO: initialize some more c++ values here, instead of doing them elsewhere and passing them in via the Ruby layer
	
	ofPixels  _bgColorPixels;
	ofTexture _bgColorTexture;
	ofShader  _bgColorShader;
	ofMesh    _bgMesh;        // likely the same across instances
	
	
	ofPixels  _fgColorPixels;
	ofTexture _fgColorTexture;
	ofShader  _fgColorShader; // should be the same across instances
	// NOTE: if you're creating multiple instances of this class, probably only need 1 mesh and 1 shader (singleton?)
	
	ofNode _bgNode;
	ofNode _fgNode;
	
	glm::vec2 _origin;
	
	ofxTerminalFont _font;
	
	std::vector<ofMesh> _meshes;
	bool bFirstTime;
	
	int _gridSizeX,_gridSizeY;
	uint32_t *_textGrid;
	
public:
	// CharMappedDisplay(){
		
	// }
	
	~CharMappedDisplay(){
		delete _textGrid;
	}
	
	
	
	int getNumCharsX(){
		return _numCharsX;
	}
	
	int getNumCharsY(){
		return _numCharsY;
	}
	
	
	
	void flushColors_bg(){
		_bgColorTexture.loadData(_bgColorPixels, GL_RGBA);
	}
	
	void flushColors_fg(){
		_fgColorTexture.loadData(_fgColorPixels, GL_RGBA);
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
	
	
	// _textGrid is a dynamic array being used as a 2D matrix (x dim major)
		uint32_t getGridCodepoint(int x, int y){
			return *(_textGrid+x+y*_gridSizeX);
		}
		
		void setGridCodepoint(int x, int y, uint32_t c){
			*(_textGrid+x+y*_gridSizeX) = c;
		}
	
	void setup_text_grid(int w, int h){
		// save dimensions for later
		_gridSizeX = w;
		_gridSizeY = h;
		
		_textGrid = new uint32_t[_gridSizeX*_gridSizeY];
		// delete _textGrid called in destructor for this class
		
		
		for(int i=0; i<_gridSizeX; i++){
			for(int j=0; j<_gridSizeY; j++){
				setGridCodepoint(i,j, 'A'+i);
			}
		}
		
		// std::cout << "block: " << getGridCodepoint(3,5) << std::endl;
		
		
		_meshes.reserve(_gridSizeY);
		for(int i=0; i<_gridSizeY; i++){
			_meshes.push_back(ofMesh());
		}
		
	}
	
	
	// TODO: consider manually inlining this inside of cpp_remesh (this function used to be inside the text class, but now that it's out here, it's a bit unnecessary...)
	
	// take character data from _textGrid (grid of UTF codepoints)
	void meshify_lines(std::vector<ofMesh> *meshes,
	                   bool bFirstTime)
	{
		PROFILER_FUNC();
		
		int size = meshes->size();
		
		for(int i=0; i<size; i++){
			uint32_t *line_ptr = _textGrid+i*_gridSizeX;
			
			_font.meshify_line(&(meshes->at(i)), 
				                line_ptr, _gridSizeX, i,
				                bFirstTime);
		}
		
	}
	
	void cpp_remesh(){
		PROFILER_FUNC();
		VALGRIND_ON;
		
		
		meshify_lines(&_meshes, bFirstTime);
		bFirstTime = false;
		
		VALGRIND_OFF;
	}
	
	// (string has already been clipped to the render field @ ruby level)
	// (just need to dump the codepoints into the grid)
	void cpp_print(int x, int y, Rice::String rb_str){
		PROFILER_FUNC();
		VALGRIND_ON;
		
		
		char const* c_str = rb_str.c_str();
		
		std::string utf8_str(c_str);
		
		int i=0;
		for(uint32_t c: ofUTF8Iterator(utf8_str)){
			setGridCodepoint(x+i,y, c);
			i++;
		}
		
		
		
		VALGRIND_OFF;
	}
	
	
	void cpp_draw(){
		// std::cout << "deep draw" << std::endl;
		_bgNode.transformGL();
		
		_bgColorShader.begin();
		_bgColorShader.setUniformTexture(
			"bgColorMap",      _bgColorTexture,           1
		);
		
		_bgMesh.draw();
		
		_bgColorShader.end();
		
		_bgNode.restoreTransformGL();
		
		
		
		
		_fgColorShader.begin();
		
		_fgColorShader.setUniformTexture(
			"trueTypeTexture", _font.getFontTexture(),    0
		);
		_fgColorShader.setUniformTexture(
			"fontColorMap",    _fgColorTexture,           1
		);
		
		_fgColorShader.setUniform2f("origin", _origin);
		// _fgColorShader.setUniform3f("charSize", glm::vec3(p2_1, p2_2, p2_3));
		
		
		_fgNode.transformGL();
		
		// text_mesh.draw();
		// TODO: iterate through meshes and draw them all
		for(int i=0; i < _meshes.size(); i++){
			_meshes[i].draw();
		}
		
		_fgColorShader.end();
		
		_fgNode.restoreTransformGL();
		
	}
	
	
	
	
	
	
	Rice::Data_Object<ofShader> bgText_getShader(){
		Rice::Data_Object<ofShader> rb_cPtr(
			&_bgColorShader,
			Rice::Data_Type< ofShader >::klass(),
			Rice::Default_Mark_Function< ofShader >::mark,
			Null_Free_Function< ofShader >::free
		);
		
		return rb_cPtr;
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
	
	Rice::Data_Object<ImageFiller> getForeground(){
		ImageFiller* helper = new ImageFiller();
		
		helper->setup(&_fgColorPixels);
		
		Rice::Data_Object<ImageFiller> rb_cPtr(helper);
		
		return rb_cPtr;
	}
	
	Rice::Data_Object<ImageFiller> getBackground(){
		ImageFiller* helper = new ImageFiller();
		
		helper->setup(&_bgColorPixels);
		
		Rice::Data_Object<ImageFiller> rb_cPtr(helper);
		
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
				_bgMesh.addTexCoord(glm::vec3(i,j, 0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+0), 0));
				_bgMesh.addTexCoord(glm::vec3(i,j, 0));
				
				_bgMesh.addVertex(glm::vec3((i+0), (j+1), 0));
				_bgMesh.addTexCoord(glm::vec3(i,j, 0));
				
				_bgMesh.addVertex(glm::vec3((i+1), (j+1), 0));
				_bgMesh.addTexCoord(glm::vec3(i,j, 0));
				
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



// void setColorPickerColor(ofParameter<ofColor_<unsigned char>> &colorParam, ofColor_<unsigned char> & color){
// 	// colorParam->r = color.r;
// 	// colorParam->g = color.g;
// 	// colorParam->b = color.b;
// 	// colorParam->a = color.a;
	
// 	// colorParam->setHex( color.getHex() )
	
// 	// colorParam->set(color);
	
// 	colorParam = color;
// }

ColorPickerInterface::ColorPickerInterface(ofxColorPicker_<unsigned char> *colorPicker){
	mColorPicker = colorPicker;
	
}

void ColorPickerInterface::setColor(ofColor &color){
	ofParameter<ofColor_<unsigned char>> &data = static_cast<ofParameter<ofColor_<unsigned char>>&>(mColorPicker->getParameter());
	
	
	data = color;
	// ^ ofParameter overloads the = operator, so to set values just use equals 
	//   (feels really weird to be able to override assignment like this...)
	
}


// TODO: need to create this object once, and then just return it again and again. wrapping this multiple times is additional overhead that makes things go slow.
Rice::Data_Object<ofColor> ColorPickerInterface::getColorPtr(){
	// ofParameter::get() returns reference to the underlying value,
	// and that is wrapped Rice::Data_Object, which is like a smart pointer.
	// This creates a ruby object that acts like C++ pointer,
	// such that changes to this object propagate to C++ automatically.
	// (because the exact same data is being edited)
	ofParameter<ofColor_<unsigned char>> &data = static_cast<ofParameter<ofColor_<unsigned char>>&>(mColorPicker->getParameter());
	
	Rice::Data_Object<ofColor> rb_color_ptr(
		&const_cast<ofColor_<unsigned char>&>(data.get()),
		Rice::Data_Type< ofColor >::klass(),
		Rice::Default_Mark_Function< ofColor >::mark,
		Null_Free_Function< ofColor >::free
	);
	
	return rb_color_ptr;
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
		
		
		.define_module_function("SpikeProfiler_begin", &SpikeProfiler_begin)
		.define_module_function("SpikeProfiler_end",   &SpikeProfiler_end)
		
		
		// .define_module_function("setColorPickerColor", &setColorPickerColor)
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
		.define_method("cpp_print",       &CharMappedDisplay::cpp_print)
		
		.define_method("getNumCharsX",   &CharMappedDisplay::getNumCharsX)
		.define_method("getNumCharsY",   &CharMappedDisplay::getNumCharsY)
		
		
		.define_method("flushColors_bg", &CharMappedDisplay::flushColors_bg)
		.define_method("flushColors_fg", &CharMappedDisplay::flushColors_fg)
		.define_method("flush",          &CharMappedDisplay::flush)
		
		
		.define_method("bgText_getShader",
			&CharMappedDisplay::bgText_getShader
		)
		
		.define_method("fgText_getShader",
			&CharMappedDisplay::fgText_getShader
		)
		.define_method("fgText_getTexture",
			&CharMappedDisplay::fgText_getTexture
		)
		
		
		.define_method("background",  &CharMappedDisplay::getBackground)
		.define_method("foreground",  &CharMappedDisplay::getForeground)
		
		
		.define_method("bgMesh_draw",
			&CharMappedDisplay::bgMesh_draw
		)
	;
	
	
	Data_Type<ImageFiller> rb_c_ofImageFiller =
		define_class_under<ImageFiller>(rb_mProject, "ImageFiller");
	
	rb_c_ofImageFiller
		.define_constructor(Constructor<ImageFiller>())
		
		
		.define_method("fill_all",    &ImageFiller::fill_all)
		.define_method("fill_bb",     &ImageFiller::fill_bb)
		.define_method("fill_row",    &ImageFiller::fill_row)
		.define_method("fill_column", &ImageFiller::fill_column)
		.define_method("fill_point",  &ImageFiller::fill_point)
		
		.define_method("color",       &ImageFiller::getColor)
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
		
		.define_method("cpp_equality", &ofxMidiMessage__equality)
	;
	
	
	// TODO: write glue code to access these fields:
	
	
	// ofxMidiOut midiOut
	
	
	
	
	
	
	Data_Type<ColorPickerInterface> rb_c_ofColorPickerInterface =
		define_class_under<ColorPickerInterface>(rb_mProject, "ColorPicker");
	
	rb_c_ofColorPickerInterface
		// .define_constructor(Constructor<ColorPickerInterface>())
		// ^ no constructor: can only be created from C++
		
		.define_method("color=",       &ColorPickerInterface::setColor)
		.define_method("getColorPtr",  &ColorPickerInterface::getColorPtr)
	;
	
	
	
	
	
	
	
	
	
	
	
	
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

int ofxMidiMessage__get_status(ofxMidiMessage &self){
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

int ofxMidiMessage__get_channel(ofxMidiMessage &self){
	return self.channel;
}
int ofxMidiMessage__get_pitch(ofxMidiMessage &self){
	return self.pitch;
}
int ofxMidiMessage__get_velocity(ofxMidiMessage &self){
	return self.velocity;
}
int ofxMidiMessage__get_value(ofxMidiMessage &self){
	return self.value;
}

double ofxMidiMessage__get_deltatime(ofxMidiMessage &self){
	return self.deltatime;
}

int ofxMidiMessage__get_portNum(ofxMidiMessage &self){
	return self.portNum;
}
std::string ofxMidiMessage__get_portName(ofxMidiMessage &self){
	return self.portName;
}


int ofxMidiMessage__get_num_bytes(ofxMidiMessage &self){
	return self.bytes.size();
}

unsigned char ofxMidiMessage__get_byte(ofxMidiMessage &self, int i){
	return self.bytes[i];
}


bool ofxMidiMessage__equality(ofxMidiMessage &self, ofxMidiMessage &other){
	if(self.bytes.size() != other.bytes.size()){
		return false;
	}
	else{
		int size = self.bytes.size();
		
		for(int i=0; i<size; i++){
			if(self.bytes[i] != other.bytes[i]){
				return false;
			}
		}
		
		return true;
	}
}
