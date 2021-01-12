#include "ofFbo.h"
#include "Fbo.h"


void ofFbo_allocate_from_struct(ofFbo& fbo, Rice::Object rb_settings){
	// Create the basic C++ data, using the struct's constructor.
	// This will get you sensible defaults.
	ofFbo::Settings s = ofFbo::Settings(nullptr);
	// ^ The argument to the Settings constructor is
	//   std::shared_ptr<ofBaseGLRenderer> renderer
	//   but can also be nullptr.
	// 
	//   This specifies the parent renderer, but for right now,
	//   should always just be nullptr.
	// 
	//   In which case, the default renderer will be used.
	//   ( accuired using ofGetGLRenderer() )
	
	
	// // Take the ruby object, and query it for additional settings.
	// // Convert to the appropriate C++ types as necessary.
	// int w = from_ruby<int>(rb_settings.call("width"));
	// int h = from_ruby<int>(rb_settings.call("height"));
	
	// // NOTE: If these accessor calls fail, you get a ruby level exception, due to the inability to find the method on the target object.
	
	Rice::Object tmp_obj;
	
	// guard against exceptions from Ruby
	// protect(rb_raise, rb_eRuntimeError, "some exception msg");
	
	// TODO: Need to figure out where the exception will be raised,
	//       if there is not property width / height, or it can't be cast to int
	
	
	// -----
	
	// =====
		// // bunch of debug code to make sure the values are coming in correctly.
		// std::cout << rb_settings.call("width") << std::endl;
		// std::cout << "width is of Ruby type: " << rb_settings.call("width").class_of() << std::endl;
		// std::cout << "width is of C++ type: " << typeid(rb_settings.call("width")).name() << std::endl;
	
		// std::cout << "width: " << w << ", " << "height: " << h  << std::endl;
	// =====
	
	
	s.width  = from_ruby<int>(rb_settings.call("width"));
	// width of images attached to fbo
	// int
	
	s.height = from_ruby<int>(rb_settings.call("height"));
	// height of images attached to fbo
	// int
	
	s.numColorbuffers = from_ruby<int>(rb_settings.call("numColorbuffers"));
	// how many color buffers to create
	// int
	
		// vector<GLint> colorFormats; // format of the color attachments for MRT.
	
	s.useDepth              = from_ruby<bool>(rb_settings.call("useDepth"));
	// whether to use depth buffer or not
	// bool
	
	s.useStencil            = from_ruby<bool>(rb_settings.call("useStencil"));
	// whether to use stencil buffer or not
	// bool	
	
	s.depthStencilAsTexture = from_ruby<bool>(rb_settings.call("depthStencilAsTexture"));
	// use a texture instead of a renderbuffer for depth (useful to draw it or use it in a shader later)
	// bool
	
	s.textureTarget      = from_ruby<GLenum>(rb_settings.call("textureTarget"));
	// GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE_ARB
	// GLenum
	
	s.internalformat     = from_ruby<GLint>(rb_settings.call("internalformat"));
	// GL_RGBA, GL_RGBA16F_ARB, GL_RGBA32F_ARB, GL_LUMINANCE32F_ARB etc.
	// GLint
	
	s.depthStencilInternalFormat = from_ruby<GLint>(rb_settings.call("depthStencilInternalFormat"));
	// GL_DEPTH_COMPONENT(16/24/32)
	// GLint
	
	s.wrapModeHorizontal = from_ruby<int>(rb_settings.call("wrapModeHorizontal"));
	// GL_REPEAT, GL_MIRRORED_REPEAT, 
	// int
	
	s.wrapModeVertical   = from_ruby<int>(rb_settings.call("wrapModeVertical"));
	// GL_REPEAT, GL_MIRRORED_REPEAT, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_BORDER etc.
	// int
	
	s.minFilter = from_ruby<int>(rb_settings.call("minFilter"));
	// GL_NEAREST, GL_LINEAR etc.
	// int
	
	s.maxFilter = from_ruby<int>(rb_settings.call("maxFilter"));
	// GL_NEAREST, GL_LINEAR etc.
	// int
	
	s.numSamples = from_ruby<int>(rb_settings.call("numSamples"));
	// number of samples for multisampling (set 0 to disable)
	// int
	
	// -----
	
	
	// Allocate the FBO
	fbo.allocate(s);
}



using namespace Rice;

Rice::Class Init_rubyOF_fbo(Rice::Module rb_mRubyOF)
{
	Data_Type<ofFbo> rb_cFbo = 
		define_class_under<ofFbo>(rb_mRubyOF, "Fbo");
	
	
	// typedef void (ofFbo::*ofFbo_allocWRAP)(int,int,int,int) const;
	// typedef void (ofFbo::*ofFbo_begin)() const;
	
	rb_cFbo
		.define_constructor(Constructor<ofFbo>())
		
		// .define_method("allocate",  ofFbo_allocWRAP(&ofFbo::allocate))
		.define_method("allocate",  &ofFbo_allocate_from_struct)
		
		// from ofFbo.h:
			/// \brief    Sets up the framebuffer and binds it for rendering.
			/// \warning  This is a convenience method, and is considered unsafe 
			///           in multi-window and/or multi-renderer scenarios.
			///           If you use more than one renderer, use each renderer's
			///           explicit void ofBaseGLRenderer::begin(const ofFbo & fbo, bool setupPerspective) 
			///           method instead.
			/// \sa       void ofBaseGLRenderer::begin(const ofFbo & fbo, bool setupPerspective)
		
		
		.define_method("begin",
			static_cast< void (ofFbo::*)
			(ofFboMode mode)
			>(&ofFbo::begin),
			(
				Arg("mode") = OF_FBOMODE_PERSPECTIVE | OF_FBOMODE_MATRIXFLIP
			)
		)
		
		.define_method("end",       &ofFbo::end)
		.define_method("bind",      &ofFbo::bind)
		.define_method("unbind",    &ofFbo::unbind)
		
		.define_method("draw_xy",
			static_cast< void (ofFbo::*)
			(float x, float y) const
			>(&ofFbo::draw)
		)
		.define_method("draw_xywh",
			static_cast< void (ofFbo::*)
			(float x, float y, float width, float height) const
			>(&ofFbo::draw)
		)
		
		
		
		
		.define_method("clearColorBuffer",
			static_cast< void (ofFbo::*)
			(size_t buffer_idx, const ofFloatColor &color)
			>(&ofFbo::clearColorBuffer)
		)
		// glClearBufferfv(GL_COLOR, 0...)
		
		.define_method("clearDepthBuffer",
			static_cast< void (ofFbo::*)
			(float value)
			>(&ofFbo::clearDepthBuffer)
		)
		// glClearBufferfv(GL_DEPTH...)
		
		.define_method("clearDepthStencilBuffer",
			static_cast< void (ofFbo::*)
			(float depth, int stencil)
			>(&ofFbo::clearDepthStencilBuffer)
		)
		// glClearBufferfi(GL_DEPTH_STENCIL...)
		
		.define_method("clearStencilBuffer",
			static_cast< void (ofFbo::*)
			(int value)
			>(&ofFbo::clearStencilBuffer)
		)
		// glClearBufferiv(GL_STENCIL...)
		
		
		.define_method("activateAllDrawBuffers",
			static_cast< void (ofFbo::*)
			(void)
			>(&ofFbo::activateAllDrawBuffers)
		)
		
		
		.define_method("getTexture",
			static_cast< ofTexture& (ofFbo::*)
			(int attachmentPoint)
			>(&ofFbo::getTexture)
		)
		
		.define_method("getTexture",
			static_cast< ofTexture& (ofFbo::*)
			(int attachmentPoint)
			>(&ofFbo::getTexture)
		)
		
		.define_method("height", &ofFbo::getHeight)
		.define_method("width",  &ofFbo::getWidth)
	;
	
	// NOTE: ofFbo.h has been patched to define "ofFbo::allocateRICE", so that I don't have to write an entirely separate wrapper class.
	// ^ this has been removed, it seems
	
	
	
	return rb_cFbo;
}
