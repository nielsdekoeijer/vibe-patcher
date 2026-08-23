pub const ShaderKind = enum {
    FRAG,
    VERT,

    pub fn glslcArgumentName(self: ShaderKind) []const u8 {
        return switch (self) {
            .FRAG => "fragment",
            .VERT => "vertex",
        };
    }

    pub fn glslcKindName(self: ShaderKind) []const u8 {
        return switch (self) {
            .FRAG => "frag",
            .VERT => "vert",
        };
    }
};

pub const Shader = struct {
    code: []const u8,
    kind: ShaderKind,
    num_samplers: u32,
    num_storage_textures: u32,
    num_storage_buffers: u32,
    num_uniform_buffers: u32,
};

pub const ShaderDescription = struct {
    path: []const u8,
    num_samplers: u32,
    num_storage_textures: u32,
    num_storage_buffers: u32,
    num_uniform_buffers: u32,
};
