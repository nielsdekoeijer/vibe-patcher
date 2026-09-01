#version 450

layout(location = 0) in vec4 inp_quad_color;

layout(location = 0) out vec4 out_quad_color;

void main() {
    out_quad_color = inp_quad_color; 
}

