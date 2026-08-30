#version 450

struct Quad { vec4 shape; vec4 color; };

layout(std430, set = 0, binding = 0) readonly buffer Quads { Quad quads[]; };
layout(std140, set = 1, binding = 0) uniform Camera { mat4 projectionMatrix; };

layout(location = 0) out vec4 out_quad_color;

void main() {
    Quad q = quads[gl_InstanceIndex];

    // NOTE: this is a smart optimization that AI came up with. We draw in multiples of 4, and essentially we can 
    // exploit this fact to get the corder
    vec2 corner = vec2(gl_VertexIndex & 1, (gl_VertexIndex >> 1) & 1);

    gl_Position = projectionMatrix * vec4(q.shape.xy + corner * q.shape.zw, 0.0, 1.0);
    out_quad_color = q.color;
}
