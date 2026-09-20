const std = @import("std");
const core = @import("core");

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = core.log_fn,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var headless = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--headless")) {
            headless = true;
        } else {
            return error.UnknownArgument;
        }
    }

    const options = core.ProgramSettings{
        .enable_gpu_debug = true,
        .shader_format = .spirv,
        .window_w = if (headless) 1280 else 640,
        .window_h = if (headless) 720 else 480,
        .headless = headless,
    };

    try core.run(options, init.gpa, init.io);
}
