#version 450

// README: https://www.redblobgames.com/articles/sdf-fonts/

struct Glyph { vec4 shape; vec4 uv; vec4 color; };

layout(std430, set = 0, binding = 0) readonly buffer Glyphs { Glyph glyphs[]; };
layout(std140, set = 1, binding = 0) uniform Camera { mat4 projectionMatrix; };

layout(location = 0) out vec2 out_glyph_uv;
layout(location = 1) out vec4 out_glyph_color;

void main() {
    Glyph glyph = glyphs[gl_InstanceIndex];

    // NOTE: this is a smart optimization that AI came up with. We draw in multiples of 4, and essentially we can 
    // exploit this fact to get the corder
    vec2 corner = vec2(gl_VertexIndex & 1, (gl_VertexIndex >> 1) & 1);

    gl_Position = projectionMatrix * vec4(glyph.shape.xy + corner * glyph.shape.zw, 0.0, 1.0);

    out_glyph_uv    = mix(glyph.uv.xy, glyph.uv.zw, corner);
    out_glyph_color = glyph.color;
}
