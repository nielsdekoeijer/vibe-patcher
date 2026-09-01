const std = @import("std");
const core = @import("core");

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = core.log_fn,
};

pub fn main(init: std.process.Init) !void {
    _ = init;

    const options = core.ProgramSettings{
        .enable_gpu_debug = true,
        .shader_format = .spirv,
        .window_w = 640,
        .window_h = 480,
    };

    try core.run(options);
}
