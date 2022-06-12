#include "callbacks.h"

#include <iostream>
#include <Poco/Runnable.h>
#include <Poco/Thread.h>

#include "Null_Free_Function.h"

#include "wrap_ofxMidi.h"

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
























void clearDepthBuffer(){
	// glClearDepth(-10000);
	glClear(GL_DEPTH_BUFFER_BIT);
}

void depthMask(bool flag){
	// std::cout << "depth mask flag (ruby val): " << flag << std::endl;
	
	if(flag){
		glDepthMask(GL_TRUE);
	}else{
		glDepthMask(GL_FALSE);
	}
}

// Note: should call this outside of any Fbo context.
//       If used while an FBO is bound, may get unexpected results.
//       (see warning below for details)
// 
// WARNING: This function does not save / restore the last used framebuffer
//          it will revert to the default buffer (buffer 0) after it completes.
void copyFramebufferByBlit__cpp(ofFbo& src, ofFbo& dst, uint flag){
	
	// shared_ptr<ofBaseGLRenderer> renderer = ofGetGLRenderer();
	
	// renderer->bindForBlitting(src, dst, 0);
	
	// renderer->unbind();
	
	
	const uint color_bit = (1 << 0);
	const uint depth_bit = (1 << 1);
	
	// std::cout << "flag: " << flag << std::endl;
	
	GLbitfield mask = 0;
	if( (flag & color_bit) == color_bit ){
		// std::cout << "color_bit" << std::endl;
		mask = mask | GL_COLOR_BUFFER_BIT;
	}
	if( (flag & depth_bit) == depth_bit ){
		// std::cout << "depth_bit" << std::endl;
		mask = mask | GL_DEPTH_BUFFER_BIT;
	}
	
	
	// default framebuffer controlled by window is 0
	// OF documentation notes that a window class might
	// change this, for instance to use MSAA, but
	// I think using the default should be fine for now.
	GLuint default_framebuffer = 0;
	
	glBindFramebuffer(GL_READ_FRAMEBUFFER, src.getId());
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, dst.getId());
	
	float width  = src.getWidth();
	float height = src.getHeight();
	glBlitFramebuffer(0,0,width,height,
	                  0,0,width,height,
							mask, GL_NEAREST);
	
	
	// target must be either GL_DRAW_FRAMEBUFFER, GL_READ_FRAMEBUFFER or GL_FRAMEBUFFER. [..] Calling glBindFramebuffer with target set to GL_FRAMEBUFFER binds framebuffer to both the read and draw framebuffer targets.
	// src: https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glBindFramebuffer.xhtml
	
	glBindFramebuffer(GL_FRAMEBUFFER, default_framebuffer);
}


void blitDefaultDepthBufferToFbo(ofFbo& fbo){
	// default framebuffer controlled by window is 0
	// OF documentation notes that a window class might
	// change this, for instance to use MSAA, but
	// I think using the default should be fine for now.
	GLuint default_framebuffer = 0;
	
	glBindFramebuffer(GL_READ_FRAMEBUFFER, default_framebuffer);
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo.getId());
	
	float width  = fbo.getWidth();
	float height = fbo.getHeight();
	glBlitFramebuffer(0,0,width,height,
	                  0,0,width,height,
							GL_DEPTH_BUFFER_BIT, GL_NEAREST);
	
	
	// target must be either GL_DRAW_FRAMEBUFFER, GL_READ_FRAMEBUFFER or GL_FRAMEBUFFER. [..] Calling glBindFramebuffer with target set to GL_FRAMEBUFFER binds framebuffer to both the read and draw framebuffer targets.
	// src: https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glBindFramebuffer.xhtml
	
	glBindFramebuffer(GL_FRAMEBUFFER, default_framebuffer);
}

void enableTransparencyBufferBlending(){
	// ofEnableDepthTest();
	
	glDepthMask(GL_FALSE);
	glEnable(GL_BLEND);
	glBlendFunci(0, GL_ONE, GL_ONE); // summation
	glBlendFunci(1, GL_ZERO, GL_ONE_MINUS_SRC_COLOR); // product of (1 - a_i)
	glBlendEquation(GL_FUNC_ADD);
	
	
	// ofPushMatrix();
	// ofScale(1,-1,1);
	// ofLoadIdentityMatrix();
}

void disableTransparencyBufferBlending(){
	glDepthMask(GL_TRUE);
	glDisable(GL_BLEND);
	
	// ofDisableDepthTest();
	// ofPopMatrix();
}



void enableScreenspaceBlending(){
	glEnable(GL_BLEND);
	glBlendEquation(GL_FUNC_ADD);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

void disableScreenspaceBlending(){
	glDisable(GL_BLEND);
}


ofMesh textureToMesh(ofTexture& tex, const glm::vec3 & pos){
	ofMesh mesh;
	
	shared_ptr<ofBaseGLRenderer> renderer = ofGetGLRenderer();
	
	// if(!renderer){
	// 	throw Rice::Exception();
	// }
	
	
	float width, height;
	width  = tex.getWidth();
	height = tex.getHeight();
	
	mesh = tex.getMeshForSubsection(pos.x,pos.y,pos.z, width, height,
										     0,0, width, height,
										     renderer->isVFlipped(),
										     renderer->getRectMode());
	
	return mesh;
}



#include "ofGLProgrammableRenderer.h"


static string shaderSource(const string & src, int major, int minor){
	string shaderSrc = src;
	ofStringReplace(shaderSrc,"%glsl_version%",ofGLSLVersionFromGL(major,minor));
#ifndef TARGET_OPENGLES
	if(major<4 && minor<2){
		ofStringReplace(shaderSrc,"%extensions%","#extension GL_ARB_texture_rectangle : enable");
	}else{
		ofStringReplace(shaderSrc,"%extensions%","");
	}
#else
	ofStringReplace(shaderSrc,"%extensions%","");
#endif
	return shaderSrc;
}

#define STRINGIFY(x) #x


#ifdef TARGET_OPENGLES
static const string vertex_shader_header =
		"%extensions%\n"
		"precision highp float;\n"
		"#define IN attribute\n"
		"#define OUT varying\n"
		"#define TEXTURE texture2D\n"
		"#define TARGET_OPENGLES\n";
static const string fragment_shader_header =
		"%extensions%\n"
		"precision highp float;\n"
		"#define IN varying\n"
		"#define OUT\n"
		"#define TEXTURE texture2D\n"
		"#define FRAG_COLOR gl_FragColor\n"
		"#define TARGET_OPENGLES\n";
#else
static const string vertex_shader_header =
		"#version %glsl_version%\n"
		"%extensions%\n"
		"#define IN in\n"
		"#define OUT out\n"
		"#define TEXTURE texture\n";
static const string fragment_shader_header =
		"#version %glsl_version%\n"
		"%extensions%\n"
		"#define IN in\n"
		"#define OUT out\n"
		"#define TEXTURE texture\n"
		"#define FRAG_COLOR fragColor\n"
		"out vec4 fragColor;\n";
#endif

static const string defaultVertexShader = vertex_shader_header + STRINGIFY(
	uniform mat4 projectionMatrix;
	uniform mat4 modelViewMatrix;
	uniform mat4 textureMatrix;
	uniform mat4 modelViewProjectionMatrix;

	IN vec4  position;
	IN vec2  texcoord;
	IN vec4  color;
	IN vec3  normal;

	OUT vec4 colorVarying;
	OUT vec2 texCoordVarying;
	OUT vec4 normalVarying;

	void main()
	{
		colorVarying = color;
		texCoordVarying = (textureMatrix*vec4(texcoord.x,texcoord.y,0,1)).xy;
		gl_Position = modelViewProjectionMatrix * position;
	}
);

// ----------------------------------------------------------------------

static const string defaultFragmentShaderTexRectNoColor = fragment_shader_header + STRINGIFY(

	uniform sampler2DRect src_tex_unit0;
	uniform float usingTexture;
	uniform float usingColors;
	uniform vec4 globalColor;

	IN float depth;
	IN vec4 colorVarying;
	IN vec2 texCoordVarying;

	void main(){
		FRAG_COLOR = TEXTURE(src_tex_unit0, texCoordVarying)* globalColor;
	}
);



void renderFboToScreen(ofFbo& fbo, ofShader& shader, int accumTex_i, int revealageTex_i){
	ofTexture& tex0 = fbo.getTexture(accumTex_i);
	ofTexture& tex1 = fbo.getTexture(revealageTex_i);
	
	glm::vec3 pos(0,0,0);
	
	// void ofGLProgrammableRenderer::draw(const ofTexture & tex, float x, float y, float z, float w, float h, float sx, float sy, float sw, float sh) const
		// void ofGLProgrammableRenderer::setAttributes(bool vertices, bool color, bool tex, bool normals)
			// void ofGLProgrammableRenderer::beginDefaultShader()
	
	shared_ptr<ofBaseGLRenderer> renderer = ofGetGLRenderer();
	
	ofGLProgrammableRenderer* render_ptr = dynamic_cast<ofGLProgrammableRenderer*>(renderer.get());
	
	// render_ptr->setAttributes(true,false,true,false);
		bool vertices = true;
		
		bool texCoordsEnabled = true;
		bool colorsEnabled = false;
		bool normalsEnabled = false;
	
	// const ofShader * nextShader = nullptr;
	
	glGetError();
	int major = render_ptr->getGLVersionMajor();
	int minor = render_ptr->getGLVersionMinor();
	
	
	ofShader defaultTexRectNoColor;
	
	defaultTexRectNoColor.setupShaderFromSource(
		GL_VERTEX_SHADER,
		shaderSource(defaultVertexShader,major, minor)
	);
	
	defaultTexRectNoColor.setupShaderFromSource(
		GL_FRAGMENT_SHADER,
		shaderSource(defaultFragmentShaderTexRectNoColor,major, minor)
	);
	
	defaultTexRectNoColor.bindDefaults();
	defaultTexRectNoColor.linkProgram();
	
	
	
	
	ofShader& currentShader = defaultTexRectNoColor;
	currentShader = shader;
	
	
	
	currentShader.begin();
	
	
	// GLenum currentTextureTarget = render_ptr->getCurrentTextureTarget();
	
	// bool usingTexture = texCoordsEnabled & (currentTextureTarget!=OF_NO_TEXTURE);
	// currentShader.setUniform1f("usingTexture",usingTexture);	
	
	// currentShader.setUniform1f("usingColors", colorsEnabled);
	
	
	if(tex0.isAllocated()) {
		// render_ptr->bind(tex0,0);
		// // ^ a shader is bound in here somewhere
		// // nextShader = &defaultTexRectNoColor;
		tex0.bind(0);
		
		ofMesh fullscreen_quad = 
			tex0.getMeshForSubsection(pos.x,pos.y,pos.z, tex0.getWidth(),tex0.getHeight(),
			                          0,0, tex0.getWidth(),tex0.getHeight(),
			                          renderer->isVFlipped(),renderer->getRectMode());
		
		// render_ptr->draw(fullscreen_quad,
		//                  OF_MESH_FILL,
		//                  colorsEnabled,texCoordsEnabled,normalsEnabled);
		
			colorsEnabled    ? fullscreen_quad.enableColors()   : fullscreen_quad.disableColors();
			texCoordsEnabled ? fullscreen_quad.enableTextures() : fullscreen_quad.disableTextures();
			normalsEnabled   ? fullscreen_quad.enableNormals()  : fullscreen_quad.disableNormals();
			
			fullscreen_quad.draw();
		
		
		// render_ptr->unbind(tex0,0);
		tex0.unbind(0);
	} else {
		ofLogWarning("ofGLProgrammableRenderer") << "draw(): texture is not allocated";
	}
	
	
	currentShader.end();
	
}









#include "ofxDynamicMaterial.h"

void ofxDynamicMaterial__setDiffuseColor(ofxDynamicMaterial& mat, const ofFloatColor &c){
   // mat.setDiffuseColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setDiffuseColor(c);
}


void ofxDynamicMaterial__setSpecularColor(ofxDynamicMaterial& mat, const ofFloatColor &c){
   // mat.setSpecularColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setSpecularColor(c);
}

void ofxDynamicMaterial__setAmbientColor(ofxDynamicMaterial& mat, const ofFloatColor &c){
   // mat.setAmbientColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setAmbientColor(c);
}

void ofxDynamicMaterial__setEmissiveColor(ofxDynamicMaterial& mat, const ofFloatColor &c){
   // mat.setEmissiveColor(ofColor_<float>(c.r/255.0,c.g/255.0,c.b/255.0,c.a/255.0));
   
   mat.setEmissiveColor(c);
}

void wrap_ofxDynamicMaterial(Module rb_mOFX){
	// NOTE: both ofxDynamicMaterial and ofMaterial are subclasses of ofBaseMaterial, but ofBaseMaterial is not bound by RubyOF. Thus, the key material interface member functions need to be bound on ofxDynamicMaterial AGAIN.
	
	Data_Type<ofxDynamicMaterial> rb_c_ofxDynamicMaterial = 
		define_class_under<ofxDynamicMaterial>(rb_mOFX, "DynamicMaterial");
	
	rb_c_ofxDynamicMaterial
      .define_constructor(Constructor<ofxDynamicMaterial>())
      
      .define_method("begin", &ofxDynamicMaterial::begin)
      .define_method("end",   &ofxDynamicMaterial::end)
      
      .define_method("ambient_color=", &ofxDynamicMaterial__setAmbientColor)
      .define_method("diffuse_color=", &ofxDynamicMaterial__setDiffuseColor)
      .define_method("specular_color=",&ofxDynamicMaterial__setSpecularColor)
      .define_method("emissive_color=",&ofxDynamicMaterial__setEmissiveColor)
      .define_method("shininess=",     &ofxDynamicMaterial::setShininess)
      
      .define_method("ambient_color",  &ofxDynamicMaterial::getAmbientColor)
      .define_method("diffuse_color",  &ofxDynamicMaterial::getDiffuseColor)
      .define_method("specular_color", &ofxDynamicMaterial::getSpecularColor)
      .define_method("emissive_color", &ofxDynamicMaterial::getEmissiveColor)
      .define_method("shininess",      &ofxDynamicMaterial::getShininess)
      
      .define_method("setCustomUniform1f",
         static_cast< void (ofxDynamicMaterial::*)
         (const std::string & name, float value)
         >(&ofxDynamicMaterial::setCustomUniform1f)
      )
      
      .define_method("setCustomUniformTexture",
         static_cast< void (ofxDynamicMaterial::*)
         (const std::string & name, const ofTexture & value, int textureLocation)
         >(&ofxDynamicMaterial::setCustomUniformTexture)
      )
      
      
      .define_method("setVertexShaderSource", 
      	&ofxDynamicMaterial::setVertexShaderSource)
      
      .define_method("setFragmentShaderSource",
      	&ofxDynamicMaterial::setFragmentShaderSource)
      
      .define_method("forceShaderRecompilation", 
      	&ofxDynamicMaterial::forceShaderRecompilation)
   ;
	
}









#include "ofxDynamicLight.h"

void wrap_ofxDynamicLight(Module rb_mOFX){
	
   Data_Type<ofxDynamicLight> rb_c_ofxDynamicLight = 
      define_class_under<ofxDynamicLight, ofNode>(rb_mOFX, "DynamicLight");
   
   rb_c_ofxDynamicLight
      .define_constructor(Constructor<ofxDynamicLight>())
		
      .define_method("enable",        &ofxDynamicLight::enable)
      .define_method("disable",       &ofxDynamicLight::disable)
      .define_method("enabled?",      &ofxDynamicLight::getIsEnabled)
      
      
      // point
      // spot
      // directional
      // area
      .define_method("getIsAreaLight",    &ofxDynamicLight::getIsAreaLight)
      .define_method("getIsDirectional",  &ofxDynamicLight::getIsDirectional)
      .define_method("getIsPointLight",   &ofxDynamicLight::getIsPointLight)
      .define_method("getIsSpotlight",    &ofxDynamicLight::getIsSpotlight)
      
      .define_method("setAreaLight",      &ofxDynamicLight::setAreaLight)
      .define_method("setDirectional",    &ofxDynamicLight::setDirectional)
      .define_method("setPointLight",     &ofxDynamicLight::setPointLight)
      .define_method("setSpotlight",      &ofxDynamicLight::setSpotlight)
      
      .define_method("getLightID",        &ofxDynamicLight::getLightID)
      
      
      .define_method("diffuse_color=",    &ofxDynamicLight::setDiffuseColor)
      .define_method("specular_color=",   &ofxDynamicLight::setSpecularColor)
      .define_method("ambient_color=",    &ofxDynamicLight::setAmbientColor)
      
      .define_method("diffuse_color",     &ofxDynamicLight::getDiffuseColor)
		.define_method("specular_color",     &ofxDynamicLight::getSpecularColor)
		.define_method("ambient_color",     &ofxDynamicLight::getAmbientColor)
   ;
}








template<typename T>
Rice::Data_Object<T> cpp_owned_rice_data(T * raw_ptr) {
	Rice::Data_Object<T> rb_cPtr(
		raw_ptr,
		Rice::Data_Type< T >::klass(),
		Rice::Default_Mark_Function< T >::mark,
		Null_Free_Function< T >::free
	);
	
	return rb_cPtr;
}


#include "EntityData.h"
#include "EntityCache.h"

void wrap_EntityData(Module rb_mProject){
	Data_Type<EntityData> rb_c_EntityData = 
      define_class_under<EntityData>(rb_mProject, "EntityData");
	
	rb_c_EntityData
		.define_constructor(Constructor<EntityData>())
		
		.define_method("initialize",      &EntityData::initialize)
		.define_method("destroy",         &EntityData::destroy)
		.define_method("active?",         &EntityData::isActive)
		.define_method("load",            &EntityData::load)
		.define_method("update",          &EntityData::update)
		
		.define_method("mesh_index",      &EntityData::getMeshIndex)
		.define_method("mesh_index=",     &EntityData::setMeshIndex)
		
		
		.define_method("copy_material", &EntityData::copyMaterial)
		
		.define_method("ambient",       &EntityData::getAmbient)
		.define_method("diffuse",       &EntityData::getDiffuse)
		.define_method("specular",      &EntityData::getSpecular)
		.define_method("emissive",      &EntityData::getEmissive)
		.define_method("alpha",         &EntityData::getAlpha)
		
		.define_method("ambient=",      &EntityData::setAmbient)
		.define_method("diffuse=",      &EntityData::setDiffuse)
		.define_method("specular=",     &EntityData::setSpecular)
		.define_method("emissive=",     &EntityData::setEmissive)
		.define_method("alpha=",        &EntityData::setAlpha)
		
		
		.define_method("copy_transform",    &EntityData::copyTransform)
		
		.define_method("position",          &EntityData::getPosition)
		.define_method("orientation",       &EntityData::getOrientation)
		.define_method("scale",             &EntityData::getScale)
		.define_method("transform_matrix",  &EntityData::getTransformMatrix)
		
		.define_method("position=",         &EntityData::setPosition)
		.define_method("orientation=",      &EntityData::setOrientation)
		.define_method("scale=",            &EntityData::setScale)
		.define_method("transform_matrix=", &EntityData::setTransformMatrix)

		
	;
}



Rice::Data_Object<EntityData>
EntityCache__getEntity(EntityCache& obj, int index){
	EntityData* raw_ptr = obj.getEntity(index);
	return cpp_owned_rice_data<EntityData>(raw_ptr);
}

void wrap_EntityCache(Module rb_mProject){
	Data_Type<EntityCache> rb_c_EntityCache = 
      define_class_under<EntityCache>(rb_mProject, "EntityCache");
	
	rb_c_EntityCache
		.define_constructor(Constructor<EntityCache>())
		
		.define_method("size",            &EntityCache::getSize)
		
		.define_method("load",            &EntityCache::load)
		.define_method("update",          &EntityCache::update)
		.define_method("flush",           &EntityCache::flush)
		
		.define_method("get_entity",      &EntityCache__getEntity)
		
		.define_method("create_entity",   &EntityCache::createEntity)
		.define_method("destroy_entity",  &EntityCache::destroyEntity)
	;
}



#include "wrap_ofxAlembic.h"

























// "main" section
extern "C"
void Init_rubyOF_project()
{
	Module rb_mRubyOF    = define_module("RubyOF");
	Module rb_mCallbacks = define_module_under(rb_mRubyOF, "CPP_Callbacks");
	
	rb_mCallbacks
		.define_module_function("test_callback", &cpp_callback)
		
		
		
		.define_module_function("ofShader_loadShaders", 
			                     &ofShader_loadShaders)
		
		.define_module_function("ofShader_bindUniforms", 
			                     &ofShader_bindUniforms)
		
		
		.define_module_function("callgrind_BEGIN", &callgrind_BEGIN)
		.define_module_function("callgrind_END",   &callgrind_END)
		
		
		.define_module_function("SpikeProfiler_begin", &SpikeProfiler_begin)
		.define_module_function("SpikeProfiler_end",   &SpikeProfiler_end)
		
		
		
		
		.define_module_function("clearDepthBuffer",
			                     &clearDepthBuffer)
		
		.define_module_function("depthMask",
			                     &depthMask)
		
		.define_module_function("blitDefaultDepthBufferToFbo",
			                     &blitDefaultDepthBufferToFbo)
		
		.define_module_function("copyFramebufferByBlit__cpp",
			                     &copyFramebufferByBlit__cpp)							
		
		
		
		.define_module_function("textureToMesh",
			                     &textureToMesh)
		
		
		.define_module_function("renderFboToScreen",
			                     &renderFboToScreen)
		
		
		
		.define_module_function("enableTransparencyBufferBlending",
			                     &enableTransparencyBufferBlending)
		.define_module_function("disableTransparencyBufferBlending",
			                     &disableTransparencyBufferBlending)
		
		
		.define_module_function("enableScreenspaceBlending",
			                     &enableScreenspaceBlending)
		.define_module_function("disableScreenspaceBlending",
			                     &disableScreenspaceBlending)
		
		
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
	
	
	// ImageFiller is used by CharMappedDisplay
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
	
	
	wrap_EntityCache(rb_mProject);
	wrap_EntityData(rb_mProject);
	
	
	
	
	
	
	Module rb_mOFX = define_module_under(rb_mRubyOF, "OFX");
	
	wrap_ofxMidi(rb_mOFX);
	wrap_ofxAlembic(rb_mOFX);
	
	wrap_ofxDynamicMaterial(rb_mOFX);
	wrap_ofxDynamicLight(rb_mOFX);
	
	
	
	
	
}
