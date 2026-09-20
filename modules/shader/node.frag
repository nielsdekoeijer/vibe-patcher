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


float sdRoundQuad(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - 0.5 * b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdCircle(vec2 p, float r)
{
    return length(p) - r;
}

void main() {
    vec2  p  = inp_node_center_position;
    float hy = 0.50 * inp_node_size.y;
    float hx = 0.25 * inp_node_size.x;
    float[6] circle_sdf = float[6](0.0, 0.0, 0.0, 0.0, 0.0, 0.0);

    float quad_sdf = sdRoundQuad(inp_node_center_position, inp_node_size, inp_node_rounding);

    for (int i = 0; i < inp_node_inplet_count; i++) {
        circle_sdf[0 + i] = sdCircle(p - vec2(-hx + i * hx, -hy), 12.0);
    }

    for (int i = 0; i < inp_node_outlet_count; i++) {
        circle_sdf[3 + i] = sdCircle(p - vec2(-hx + i * hx,  hy), 12.0);
    }

    float comb_sdf = quad_sdf;
    float bb_circ = 1.0;
    for (int i = 0; i < 6; i++) {
        comb_sdf = min(comb_sdf, circle_sdf[i]);

        float aa_circ = fwidth(comb_sdf);

        bb_circ = bb_circ * smoothstep(-inp_node_border_width - aa_circ, 
                                       -inp_node_border_width + aa_circ, circle_sdf[i]);
    }

    float aa_quad = fwidth(quad_sdf);
    float aa_comb = fwidth(comb_sdf);

    float bb_quad = smoothstep(-inp_node_border_width - aa_quad, -inp_node_border_width + aa_quad, quad_sdf);
    float cover   = smoothstep(-inp_node_border_width - aa_comb, -inp_node_border_width + aa_comb, comb_sdf);

    vec3  rgb = mix(inp_node_inner_color.rgb, inp_node_outer_color.rgb, 1.0 - (1.0 - bb_quad) * bb_circ);
    float a   = mix(inp_node_inner_color.a,   inp_node_outer_color.a,   cover);

    float alpha   = 1.0 - smoothstep(-aa_quad, aa_quad, quad_sdf);

    out_node_color = vec4(rgb, a * alpha);
}
