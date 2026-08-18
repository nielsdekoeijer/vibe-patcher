const std = @import("std");
const vibe_patcher = @import("vibe_patcher");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const options = vibe_patcher.ProgramSettings {
        .enable_gpu_debug = true,
        .shader_format = .spirv,
    };

    try vibe_patcher.run(options);
}
