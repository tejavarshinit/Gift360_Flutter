#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture_input;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 color = texture(u_texture_input, uv);
  float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
  // Only the navy "Gift" word. Gold "360" stays gold, including its dark edges.
  bool navyWord = color.a > 0.25 &&
      color.b > color.r + 0.06 &&
      color.b > color.g &&
      luma < 0.5 &&
      luma > 0.08;
  if (navyWord) {
    frag_color = vec4(1.0, 0.97, 0.92, color.a);
  } else {
    frag_color = color;
  }
}
