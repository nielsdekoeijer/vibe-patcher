#version 450

struct Node { 
    vec4 shape; 
    vec4 inner_color; 
    vec4 outer_color; 
    float rounding; 
    float border_width_px;
    float inplet_count;
    float outlet_count;
};

layout(std430, set = 0, binding = 0) readonly buffer Nodes { Node nodes[]; };

layout(std140, set = 1, binding = 0) uniform Camera { mat4 projectionMatrix; };

layout(location = 0) out vec2 out_node_center_position;
layout(location = 1) flat out vec4 out_node_inner_color;
layout(location = 2) flat out vec4 out_node_outer_color;
layout(location = 3) flat out vec2 out_node_size;
layout(location = 4) flat out float out_node_rounding;
layout(location = 5) flat out float out_node_border_width;
layout(location = 6) flat out float out_node_inplet_count;
layout(location = 7) flat out float out_node_outlet_count;

void main() {
    Node q = nodes[gl_InstanceIndex];

    // NOTE: this is a smart optimization that AI came up with. We draw in multiples of 4, and essentially we can 
    // exploit this fact to get the corder
    vec2 corner = vec2(gl_VertexIndex & 1, (gl_VertexIndex >> 1) & 1);

    // Our position
    vec2 pos = q.shape.xy + corner * q.shape.zw;

    gl_Position = projectionMatrix * vec4(pos, 0.0, 1.0);

    out_node_center_position = (corner - 0.5) * q.shape.zw;
    out_node_inner_color = q.inner_color;
    out_node_outer_color = q.outer_color;
    out_node_size = q.shape.zw;
    out_node_rounding = q.rounding;
    out_node_border_width = q.border_width_px;
    out_node_inplet_count = q.inplet_count;
    out_node_outlet_count = q.outlet_count;
}
