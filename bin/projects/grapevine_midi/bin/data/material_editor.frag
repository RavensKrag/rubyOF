// fragment shader

#version 150

// from the previous stage of pipeline (vertex shader)
in vec2 f_texcoord;
in vec4 f_position;

// inputs to the fragment shader specifically
uniform sampler2DRect tex0;
uniform sampler2DRect tex1;
out vec4 outputColor;

void main()
{
  // gl_FragCoord contains the window relative coordinate for the fragment.
  // we use gl_FragCoord.x position to control the red color value.
  // we use gl_FragCoord.y position to control the green color value.
  // please note that all r, g, b, a values are between 0 and 1.

  float windowWidth = 1024.0;
  float windowHeight = 768.0;
  
  float r = gl_FragCoord.x / windowWidth;
  float g = gl_FragCoord.y / windowHeight;
  float b = 1.0;
  float a = 1.0;
  outputColor = vec4(r, g, b, a);
  
  // outputColor = gl_Color;
  
  
  // texture() returns normalized RGBA color
  // src: https://forum.openframeworks.cc/t/what-does-the-texture-function-in-glsl-do/21196
  
  // vec4 text_color = texture(tex0, vec2(gl_FragCoord.x, gl_FragCoord.y));
  // float r = text_color[0];
  // float g = text_color[1];
  // float b = text_color[2];
  // float a = text_color[3];
  // outputColor = vec4(r,g,b,a);
  // outputColor = text_color;
  
  // coordinates sampler2DRect are texel values, not normalized coordinates
  // src: https://www.khronos.org/opengl/wiki/Rectangle_Texture
  // outputColor = texture(tex1, vec2(0, 0 + 0.5));
  
}
