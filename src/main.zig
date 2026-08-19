const std = @import("std");
const vibe_patcher = @import("vibe_patcher");

pub const std_options = std.Options {
    .log_level = .info,
};

pub fn main(init: std.process.Init) !void {
    _ = init;

    const options = vibe_patcher.ProgramSettings {
        .enable_gpu_debug = true,
        .shader_format = .spirv,
        .window_w = 640,
        .window_h = 480,
    };

    try vibe_patcher.run(options);
}
