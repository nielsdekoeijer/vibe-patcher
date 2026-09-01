#version 450

layout(location = 0) in  vec2 canvas_uv;
layout(location = 0) out vec4 canvas_out_color;

layout(std140, set = 3, binding = 0) uniform CanvasUniform {
    vec4 background_color;
    vec4 major_grid_color;
    vec4 minor_grid_color;

    float minor_grid_spacing_em;
    float minor_grid_width_px;

    float major_grid_spacing_em;
    float major_grid_width_px;

    vec2 viewport_px;
    vec2 camera_em;
    float camera_zoom;
} u_config;

float gridMask(vec2 world_position_em, float spacing_em, float line_width_px) {
      vec2 grid_coordinate_em = world_position_em / spacing_em;

      vec2 distance_to_peak = abs(fract(grid_coordinate_em - 0.5) - 0.5);

      vec2 distance_px = distance_to_peak / fwidth(grid_coordinate_em);

      float nearest_line_px =
          min(distance_px.x, distance_px.y);

      return 1.0 - smoothstep(
          line_width_px * 0.5,
          line_width_px * 0.5 + 1.0,
          nearest_line_px
      );
  }

void main() {
    vec2 canvas_px = canvas_uv * u_config.viewport_px;

    vec2 world_position_em = u_config.camera_em + canvas_px / u_config.camera_zoom;

    vec4 color = u_config.background_color;

    float minor_grid = gridMask(world_position_em, u_config.minor_grid_spacing_em, u_config.minor_grid_width_px);
    color = mix(color, u_config.minor_grid_color, minor_grid * u_config.minor_grid_color.a);

    float major_grid = gridMask(world_position_em, u_config.major_grid_spacing_em, u_config.major_grid_width_px);
    color = mix(color, u_config.major_grid_color, major_grid * u_config.major_grid_color.a);

    color.a = 1.0;
    canvas_out_color = color;
}
