#version 450

layout(location = 0) in vec2 inp_node_center_position;
layout(location = 1) flat in vec4 inp_node_inner_color;
layout(location = 2) flat in vec4 inp_node_outer_color;
layout(location = 3) flat in vec2 inp_node_size;
layout(location = 4) flat in float inp_node_rounding;
layout(location = 5) flat in float inp_node_border_width;
layout(location = 6) flat in float inp_node_inplet_count;
layout(location = 7) flat in float inp_node_outlet_count;

layout(location = 0) out vec4 out_node_color;

const int MAX_PORTS = 16;

void main() {
    out_node_color = inp_node_inner_color; 
}
