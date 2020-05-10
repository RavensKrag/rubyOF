// fragment shader

#version 150

// from the previous stage of pipeline (vertex shader)
in vec2 f_texcoord;

// inputs to the fragment shader specifically
uniform sampler2DRect trueTypeTexture;
uniform sampler2DRect fontColorMap;
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
  // outputColor = vec4(r, g, b, a);
  
  // outputColor = gl_Color;
  
  outputColor = texture(fontColorMap, vec2(0,0));
}
