#version 450

// README: https://www.redblobgames.com/articles/sdf-fonts/

/// The point we are sampling from the font atlas
layout(location = 0) in vec2 inp_glyph_uv;

/// The color of our font
layout(location = 1) in vec4 inp_glpyh_color;

/// Our font atlas
layout(set = 2, binding = 0) uniform sampler2D u_msdf_atlas;

layout(std140, set = 3, binding = 0) uniform GlyphUniform { vec2 aem_range; float threshold_em; float antialias_per_em; } u_config;

/// Final color to write
layout(location = 0) out vec4 out_glyph_color;

float screen_px_scale(vec2 uv) {
  vec2 atlas_size = vec2(textureSize(u_msdf_atlas, 0));
  vec2 gradient = fwidth(uv);
  vec2 product = atlas_size * gradient;
  return max(0.5 * dot(atlas_size, gradient) / (product.x * product.y), 1.0);
}

float median(vec3 rgb) {
  return max(min(rgb.r, rgb.g), min(max(rgb.r, rgb.g), rgb.b));
}

void main() {
    float texel = median(texture(u_msdf_atlas, inp_glyph_uv).rgb);
    float distance_em = mix(u_config.aem_range[1], u_config.aem_range[0], texel);
    float inverse_width = screen_px_scale(inp_glyph_uv) * u_config.antialias_per_em;
    float opacity = clamp((u_config.threshold_em - distance_em) * inverse_width + 0.5, 0.0, 1.0);

    out_glyph_color = vec4(
      inp_glpyh_color.rgb,
      inp_glpyh_color.a * opacity
    );
}
