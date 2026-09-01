#version 450

layout(location = 0) in vec4 inp_node_color;

layout(location = 0) out vec4 out_node_color;

void main() {
    out_node_color = inp_node_color; 
}

