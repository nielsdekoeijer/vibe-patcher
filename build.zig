const std = @import("std");

const ShaderKind = @import("modules/shader/root.zig").ShaderKind;

/// Helper wrapper around the shader module.
///
/// Helps us ensure that each shader we compile (which uses the shader module) links to a common module.
const ShaderModule = struct {
    module: *std.Build.Module,

    pub fn init(b: *std.Build, target: std.Build.ResolvedTarget) ShaderModule {
        return ShaderModule{ .module = b.addModule("shader", .{
            .root_source_file = b.path("modules/shader/root.zig"),
            .target = target,
        }) };
    }

    /// Appends a zig file with a shader module byte code inside of it in a fixed way
    pub fn appendShaderModule(
        self: ShaderModule,
        b: *std.Build,
        m: *std.Build.Module,
        kind: ShaderKind,
        inp_path: std.Build.LazyPath,
        out_name: []const u8,
    ) void {
        const comm_name = kind.glslcArgumentName();
        const kind_name = kind.glslcKindName();

        const command = b.addSystemCommand(&.{"glslc"});
        command.addArg(b.fmt("-fshader-stage={s}", .{comm_name}));
        command.addArg("--target-env=vulkan1.0");
        command.addArg("-o");
        const spirv = command.addOutputFileArg(b.fmt("{s}.{s}.spv", .{ out_name, kind_name }));
        command.addFileArg(inp_path);

        const temp_file = b.addWriteFiles();
        const temp_file_path = temp_file.add(
            b.fmt("{s}.{s}.zig", .{ out_name, kind_name }),
            b.fmt(
                \\const lib = @import("shader");
                \\const spirv align(4) = @embedFile("shader.spv").*;
                \\pub const shader = lib.Shader{{
                \\    .kind = .{s},
                \\    .code = &spirv,
                \\}};
            , .{@tagName(kind)}),
        );

        const module = b.createModule(.{ .root_source_file = temp_file_path });
        module.addImport("shader", self.module);
        module.addAnonymousImport("shader.spv", .{ .root_source_file = spirv });

        m.addImport(b.fmt("{s}_{s}", .{ out_name, kind_name }), module);
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shader = ShaderModule.init(b, target);

    const core = b.addModule("core", .{
        .root_source_file = b.path("modules/core/root.zig"),
        .target = target,
    });
    core.addImport("shader", shader.module);

    shader.appendShaderModule(b, core, .VERT, b.path("modules/shader/triangle.vert"), "triangle");
    shader.appendShaderModule(b, core, .FRAG, b.path("modules/shader/triangle.frag"), "triangle");
    shader.appendShaderModule(b, core, .VERT, b.path("modules/shader/quad.vert"), "quad");
    shader.appendShaderModule(b, core, .FRAG, b.path("modules/shader/quad.frag"), "quad");


    const sdl = b.dependency("sdl", .{
        .optimize = optimize,
        .target = target,
    });
    core.addImport("sdl3", sdl.module("sdl3"));

    const exe = b.addExecutable(.{
        .name = "vibe_patcher",
        .root_module = b.createModule(.{
            .root_source_file = b.path("modules/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = core,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
