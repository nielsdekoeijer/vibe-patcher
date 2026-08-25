const std = @import("std");

const ShaderKind = @import("modules/shader/root.zig").ShaderKind;
const ShaderDescription = @import("modules/shader/root.zig").ShaderDescription;
const FontDescription = @import("modules/font/root.zig").FontDescription;

/// Helper wrapper around the shader module.
///
/// Helps us ensure that each shader we compile (which uses the shader module) links to a common module.
const ShaderModule = struct {
    const shader_manifest = @import("modules/shader/manifest.zon");
    module: *std.Build.Module,

    pub fn init(b: *std.Build, target: std.Build.ResolvedTarget) ShaderModule {
        return ShaderModule{
            .module = b.addModule("shader", .{
                .root_source_file = b.path("modules/shader/root.zig"),
                .target = target,
            }),
        };
    }

    /// Appends a zig file with a shader module byte code inside of it in a fixed way
    fn appendShaderModule(
        self: ShaderModule,
        b: *std.Build,
        m: *std.Build.Module,
        kind: ShaderKind,
        import_name: []const u8,
        entry: ShaderDescription,
    ) void {
        const comm_name = kind.glslcArgumentName();
        const command = b.addSystemCommand(&.{"glslc"});
        command.addArg(b.fmt("-fshader-stage={s}", .{comm_name}));
        command.addArg("--target-env=vulkan1.0");
        command.addArg("-o");
        const spirv = command.addOutputFileArg(b.fmt("{s}.spv", .{import_name}));
        command.addFileArg(b.path(entry.path));

        const temp_file = b.addWriteFiles();
        const temp_file_path = temp_file.add(
            b.fmt("{s}.zig", .{import_name}),
            b.fmt(
                \\const lib = @import("shader");
                \\const spirv align(4) = @embedFile("shader.spv").*;
                \\pub const shader = lib.Shader{{
                \\    .kind = .{s},
                \\    .code = &spirv,
                \\    .num_samplers = {d},
                \\    .num_storage_textures = {d},
                \\    .num_storage_buffers = {d},
                \\    .num_uniform_buffers = {d},
                \\}};
            , .{
                @tagName(kind),
                entry.num_samplers,
                entry.num_storage_textures,
                entry.num_storage_buffers,
                entry.num_uniform_buffers,
            }),
        );

        const module = b.createModule(.{ .root_source_file = temp_file_path });
        module.addImport("shader", self.module);
        module.addAnonymousImport("shader.spv", .{ .root_source_file = spirv });
        m.addImport(import_name, module);
    }

    pub fn appendManifest(self: ShaderModule, b: *std.Build, m: *std.Build.Module) void {
        inline for (std.meta.fields(@TypeOf(shader_manifest.verts))) |field| {
            const entry = @field(shader_manifest.verts, field.name);
            self.appendShaderModule(b, m, .VERT, b.fmt("{s}_vert", .{field.name}), ShaderDescription{
                .path = entry.path,
                .num_samplers = entry.num_samplers,
                .num_storage_textures = entry.num_storage_textures,
                .num_storage_buffers = entry.num_storage_buffers,
                .num_uniform_buffers = entry.num_uniform_buffers,
            });
        }

        inline for (std.meta.fields(@TypeOf(shader_manifest.frags))) |field| {
            const entry = @field(shader_manifest.frags, field.name);
            self.appendShaderModule(b, m, .FRAG, b.fmt("{s}_frag", .{field.name}), ShaderDescription{
                .path = entry.path,
                .num_samplers = entry.num_samplers,
                .num_storage_textures = entry.num_storage_textures,
                .num_storage_buffers = entry.num_storage_buffers,
                .num_uniform_buffers = entry.num_uniform_buffers,
            });
        }
    }
};

/// Helper wrapper around the font module.
const FontModule = struct {
    const font_manifest = @import("modules/font/manifest.zon");
    module: *std.Build.Module,

    pub fn init(b: *std.Build, target: std.Build.ResolvedTarget) FontModule {
        return FontModule{
            .module = b.addModule("font", .{
                .root_source_file = b.path("modules/font/root.zig"),
                .target = target,
            }),
        };
    }

    /// Appends a zig file with a font module byte code inside of it in a fixed way
    fn appendFontModule(
        self: FontModule,
        b: *std.Build,
        m: *std.Build.Module,
        import_name: []const u8,
        entry: FontDescription,
    ) void {
        const command = b.addSystemCommand(&.{"msdf-atlas-gen"});
        command.addArg("-font");
        command.addArg(b.fmt("{s}", .{entry.path}));
        command.addArg("-type");
        command.addArg(b.fmt("msdf", .{}));
        command.addArg("-format");
        command.addArg(b.fmt("png", .{}));
        command.addArg("-size");
        command.addArg(b.fmt("32", .{}));
        command.addArg("-pxrange");
        command.addArg(b.fmt("4", .{}));

        command.addArg("-imageout");
        const data = command.addOutputFileArg(b.fmt("{s}.png", .{import_name}));

        command.addArg("-json");
        const json = command.addOutputFileArg(b.fmt("{s}.json", .{import_name}));

        const temp_file = b.addWriteFiles();
        const temp_file_path = temp_file.add(
            b.fmt("{s}.zig", .{import_name}),
            b.fmt(
                \\const data align(4) = @embedFile(\"data\").*
                \\const json align(4) = @embedFile(\"json\").*
            , .{}),
        );

        const module = b.createModule(.{ .root_source_file = temp_file_path });
        module.addImport("font", self.module);
        module.addAnonymousImport("data", .{ .root_source_file = data });
        module.addAnonymousImport("json", .{ .root_source_file = json });
        m.addImport(import_name, module);
    }

    pub fn appendManifest(self: FontModule, b: *std.Build, m: *std.Build.Module) void {
        inline for (std.meta.fields(@TypeOf(font_manifest.fonts))) |field| {
            const entry = @field(font_manifest.fonts, field.name);
            self.appendFontModule(b, m, b.fmt("{s}", .{field.name}), FontDescription{
                .path = entry.path,
            });
        }
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shader = ShaderModule.init(b, target);
    const font = FontModule.init(b, target);

    const core = b.addModule("core", .{
        .root_source_file = b.path("modules/core/root.zig"),
        .target = target,
    });
    core.addImport("shader", shader.module);

    shader.appendManifest(b, core);
    font.appendManifest(b, core);

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
