const std = @import("std");
const sdl = @import("sdl3");
const font_module = @import("font");
const shader_module = @import("shader");

const CanvasVert = @import("canvas_vert").shader;
const CanvasFrag = @import("canvas_frag").shader;

const QuadVert = @import("quad_vert").shader;
const QuadFrag = @import("quad_frag").shader;

const GlyphVert = @import("glyph_vert").shader;
const GlyphFrag = @import("glyph_frag").shader;

const DefaultFont = @import("atikinsons_hyperlegible_regular_14").font;
const MonoFont = @import("atikinsons_hyperlegible_mono_regular_14").font;

/// Comptime helper
fn hexColor(comptime hex: []const u8, alpha: f32) [4]f32 {
    if (hex.len != 7 or hex[0] != '#') @compileError("expected #RRGGBB");
    return .{
        @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable)) / 255.0,
        @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable)) / 255.0,
        @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable)) / 255.0,
        alpha,
    };
}

/// Helper struct for our projection matrix
pub const ProjectionMatrixUniform = extern struct {
    data: [16]f32,

    pub fn ortho(x: f32, y: f32, w: f32, h: f32) ProjectionMatrixUniform {
        var data: [16]f32 = std.mem.zeroes([16]f32);

        data[0] = 2.0 / w;
        data[5] = 2.0 / -h;

        data[10] = 1.0;
        data[12] = (2.0 * x + w) / -w;
        data[13] = (2.0 * y + h) / h;
        data[15] = 1.0;

        return .{
            .data = data,
        };
    }

    pub fn screen(w: u32, h: u32) ProjectionMatrixUniform {
        return ortho(0, 0, @floatFromInt(w), @floatFromInt(h));
    }
};

/// Camera struct for describing our Camera2D
pub const Camera2D = struct {
    position: [2]f32,
    zoom: f32,

    pub fn init() Camera2D {
        return .{
            .position = @splat(0),
            .zoom = 1.0,
        };
    }

    pub fn center_zoom(self: *Camera2D, center: [2]f32, factor: f32) void {
        const anchor = [2]f32{
            self.position[0] + center[0] / self.zoom,
            self.position[1] + center[1] / self.zoom,
        };

        const zoom = self.zoom * factor;

        self.position = .{
            anchor[0] - center[0] / zoom,
            anchor[1] - center[1] / zoom,
        };

        self.zoom = zoom;
    }

    pub fn drag(self: *Camera2D, dx: f32, dy: f32) void {
        self.position[0] -= dx / self.zoom;
        self.position[1] -= dy / self.zoom;
    }
};

/// Helper struct for our projection matrix
pub const CanvasUniform = extern struct {
    background_color: [4]f32,
    major_grid_color: [4]f32,
    minor_grid_color: [4]f32,

    minor_grid_spacing_em: f32,
    minor_grid_width_px: f32,

    major_grid_spacing_em: f32,
    major_grid_width_px: f32,

    viewport_px: [2]f32,
    camera_em: [2]f32,
    camera_zoom: f32,

    _padding: [3]f32,

    pub fn init(canvas: CanvasElement) CanvasUniform {
        return .{
            .background_color = ClearColorHex,
            .minor_grid_color = hexColor("#293241", 0.2),
            .major_grid_color = hexColor("#3A4659", 0.4),

            .minor_grid_spacing_em = 24.0,
            .minor_grid_width_px = 1.0,

            .major_grid_spacing_em = 120.0,
            .major_grid_width_px = 1.0,

            .viewport_px = .{
                canvas.bounding_box[2],
                canvas.bounding_box[3],
            },
            .camera_em = .{
                canvas.camera.position[0],
                canvas.camera.position[1],
            },
            .camera_zoom = canvas.camera.zoom,

            ._padding = @splat(0),
        };
    }
};

/// Helper struct that manages the quad for the GPU
pub const QuadInstance = extern struct {
    const VertexCount = 4;

    shape: [4]f32,
    color: [4]f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32, color: [4]f32) QuadInstance {
        return QuadInstance{
            .shape = .{ x, y, w, h },
            .color = color,
        };
    }
};

/// Helper struct for glyphs
pub const GlyphUniform = extern struct {
    aem_range: [2]f32,
    threshold_em: f32,
    antialias_per_em: f32,

    pub fn init(comptime configuration: type) GlyphUniform {
        return GlyphUniform{
            .aem_range = configuration.aem_range,
            .threshold_em = 0.0,
            .antialias_per_em = configuration.pixels_per_em,
        };
    }
};

/// Helper struct that manages the glyph for the GPU
pub const GlyphInstance = extern struct {
    const VertexCount = 4;

    shape: [4]f32,
    uv: [4]f32,
    color: [4]f32,

    pub fn init(
        comptime config: font_module.FontConfiguration,
        char: u8,
        pos: *[2]f32,
        color: [4]f32,
    ) ?GlyphInstance {
        const glyph = &font_module.FontAtlas(config).CharacterGlyphs[char];

        const glyph_x = pos[0];
        pos[0] += glyph.x_advance;

        if (glyph.quad) |g| {
            return GlyphInstance{
                .shape = .{
                    glyph_x + g.shape[0],
                    pos[1] - g.shape[1],
                    g.shape[2],
                    g.shape[3],
                },
                .uv = g.uv,
                .color = color,
            };
        }

        return null;
    }

    pub fn text(
        comptime config: font_module.FontConfiguration,
        string: []const u8,
        cursor: *[2]f32,
        color: [4]f32,
        out: []GlyphInstance,
    ) usize {
        var index: usize = 0;

        for (string) |char| {
            out[index] = GlyphInstance.init(config, char, cursor, color) orelse continue;
            index += 1;
        }

        return index;
    }

    pub fn rect(
        comptime config: font_module.FontConfiguration,
        string: []const u8,
    ) [2]f32 {
        var cursor: [2]f32 = @splat(0);

        for (string) |char| {
            const glyph = &font_module.FontAtlas(config).CharacterGlyphs[char];

            cursor[0] += glyph.x_advance;

            if (glyph.quad) |quad| {
                cursor[1] = @max(cursor[1], quad.shape[3]);
            }
        }

        return cursor;
    }
};

/// Describes the UI component
pub const UserInterface = struct {
    menubar: MenubarElement,

    toolbar: ToolbarElement,

    selector: SelectorElement,

    inspector: InspectorElement,

    console: ConsoleElement,

    status: StatusElement,

    canvas: CanvasElement,

    dirty: bool,

    pub fn resize(self: *UserInterface, w: f32, h: f32) void {
        self.menubar = MenubarElement.init(0, 0, w, h);

        const toolbar_y = MenubarElement.BarHeight;
        self.toolbar = .init(0, toolbar_y, w, h);

        const selector_y = toolbar_y + ToolbarElement.BarHeight;
        const selector_h = h - MenubarElement.BarHeight - ToolbarElement.BarHeight - StatusElement.BarHeight;
        self.selector = .init(0, selector_y, w, selector_h);

        const inspector_x = w - InspectorElement.BarWidth;
        const inspector_y = selector_y;
        const inspector_h = selector_h;
        self.inspector = .init(inspector_x, inspector_y, w, inspector_h);

        const status_y = h - StatusElement.BarHeight;
        self.status = .init(0, status_y, w, h);

        const console_x = SelectorElement.BarWidth;
        const console_y = h - ConsoleElement.BarHeight - StatusElement.BarHeight;
        const console_w = w - InspectorElement.BarWidth - SelectorElement.BarWidth;
        const console_h = h;
        self.console = .init(console_x, console_y, console_w, console_h);

        const canvas_x = SelectorElement.BarWidth;
        const canvas_y = MenubarElement.BarHeight + ToolbarElement.BarHeight;
        const canvas_w = w - SelectorElement.BarWidth - InspectorElement.BarWidth;
        const canvas_h = h - canvas_y - ConsoleElement.BarHeight - StatusElement.BarHeight;
        self.canvas = .init(canvas_x, canvas_y, canvas_w, canvas_h);

        self.dirty = true;
    }

    pub fn generate_quad_instances(self: UserInterface, out: []QuadInstance) usize {
        var index: usize = 0;

        index += self.status.generate_quad_instances(out[index..]);

        index += self.menubar.generate_quad_instances(out[index..]);
        index += self.toolbar.generate_quad_instances(out[index..]);
        index += self.console.generate_quad_instances(out[index..]);

        index += self.selector.generate_quad_instances(out[index..]);
        index += self.inspector.generate_quad_instances(out[index..]);

        return index;
    }

    pub fn generate_default_glyph_instances(self: UserInterface, out: []GlyphInstance) usize {
        var index: usize = 0;

        index += self.menubar.generate_glyph_instances(out[index..]);

        return index;
    }

    pub fn generate_mono_glyph_instances(self: UserInterface, out: []GlyphInstance) usize {
        var index: usize = 0;

        index += self.toolbar.generate_glyph_instances(out[index..]);

        return index;
    }

    pub fn init(w: f32, h: f32) UserInterface {
        var interface: UserInterface = undefined;

        interface.resize(w, h);

        return interface;
    }
};

/// Describes the menubar
pub const MenubarElement = struct {
    pub const TextColor = hexColor("#171E29", 1.0);
    pub const TextCursor: [2]f32 = .{ 15, 17 };
    pub const BackgroundColor = hexColor("#F1F5FA", 1.0);
    pub const HoverColor = hexColor("#DCE6F5", 1.0);
    pub const BarHeight: f32 = 24.0;
    pub const OptionPadding: f32 = 10.0;

    const Option = struct {
        name: []const u8,
        rect: [2]f32,

        pub fn init(name: []const u8) Option {
            return .{
                .name = name,
                .rect = GlyphInstance.rect(DefaultFont.config, name),
            };
        }

        pub fn append_glypths(self: Option, cursor: *[2]f32, out: []GlyphInstance) usize {
            return GlyphInstance.text(DefaultFont.config, self.name, cursor, MenubarElement.TextColor, out);
        }
    };

    pub const Options = [_]Option{ .init("File"), .init("Edit"), .init("View"), .init("Object") };

    bounding_box: [4]f32,
    hovered_option_index: ?usize,

    pub fn init(x: f32, y: f32, w: f32, h: f32) MenubarElement {
        _ = h;

        return MenubarElement{
            .bounding_box = .{ x, y, w, BarHeight },
            .hovered_option_index = null,
        };
    }

    pub fn update_hover(self: *MenubarElement, x: f32, y: f32) bool {
        const previous = self.hovered_option_index;
        self.hovered_option_index = null;

        if (y >= self.bounding_box[1] and y < self.bounding_box[1] + self.bounding_box[3]) {
            var cursor_x = TextCursor[0];

            for (Options, 0..) |option, index| {
                const l = cursor_x - OptionPadding;
                const r = cursor_x + option.rect[0] + OptionPadding;

                if (x >= l and x < r) {
                    self.hovered_option_index = index;
                    break;
                }

                cursor_x = r + OptionPadding;
            }
        }

        return previous != self.hovered_option_index;
    }

    pub fn generate_glyph_instances(self: MenubarElement, out: []GlyphInstance) usize {
        _ = self;

        var index: usize = 0;
        var cursor = MenubarElement.TextCursor;

        for (MenubarElement.Options) |option| {
            index += option.append_glypths(&cursor, out[index..]);
            cursor[0] += OptionPadding * 2;
        }

        return index;
    }

    pub fn generate_quad_instances(self: MenubarElement, out: []QuadInstance) usize {
        out[0] = .{
            .color = MenubarElement.BackgroundColor,
            .shape = self.bounding_box,
        };

        const hovered = self.hovered_option_index orelse return 1;

        var cursor_x = TextCursor[0];
        for (Options[0..hovered]) |option| {
            cursor_x += option.rect[0] + OptionPadding * 2;
        }

        out[1] = QuadInstance.init(
            cursor_x - OptionPadding,
            self.bounding_box[1],
            Options[hovered].rect[0] + OptionPadding * 2,
            self.bounding_box[3],
            HoverColor,
        );

        return 2;
    }
};

pub const CanvasElement = struct {
    pub const BackgroundColor = ClearColorHex;
    pub const GridColor = hexColor("#293241", 1.0);
    pub const GridSpacing: f32 = 24.0;
    pub const GridLineWidth: f32 = 1.0;

    bounding_box: [4]f32,
    dragging: bool,
    camera: Camera2D,

    pub fn init(x: f32, y: f32, w: f32, h: f32) CanvasElement {
        return CanvasElement{
            .bounding_box = .{ x, y, w, h },
            .dragging = false,
            .camera = .init(),
        };
    }

    pub fn contains(self: CanvasElement, x: f32, y: f32) bool {
        if (y < self.bounding_box[1] and y >= self.bounding_box[1] + self.bounding_box[3]) {
            return false;
        }

        if (x < self.bounding_box[0] and x >= self.bounding_box[0] + self.bounding_box[2]) {
            return false;
        }

        return true;
    }
};

pub const ToolbarElement = struct {
    pub const TextColor = hexColor("#F1F5FA", 1.0);
    pub const BackgroundColor = hexColor("#202A38", 1.0);
    pub const BarHeight: f32 = 24.0;
    pub const ZoomTextCursor: [2]f32 = .{ 10, 17 };

    bounding_box: [4]f32,
    zoom: f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) ToolbarElement {
        _ = h;

        return ToolbarElement{
            .bounding_box = .{ x, y, w, BarHeight },
            .zoom = 100,
        };
    }

    pub fn generate_glyph_instances(self: ToolbarElement, out: []GlyphInstance) usize {
        var cursor: [2]f32 = .{
            ToolbarElement.ZoomTextCursor[0],
            ToolbarElement.ZoomTextCursor[1] + self.bounding_box[1],
        };

        const val: u32 = std.math.clamp(@as(u32, @intFromFloat(self.zoom)), 0, 9999);

        var buf: [5]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d:4}%", .{val}) catch return 0;
        return GlyphInstance.text(MonoFont.config, text, &cursor, TextColor, out);
    }

    pub fn generate_quad_instances(self: ToolbarElement, quads: []QuadInstance) usize {
        quads[0] = .{
            .color = ToolbarElement.BackgroundColor,
            .shape = self.bounding_box,
        };

        return 1;
    }
};

pub const SelectorElement = struct {
    pub const TextColor = hexColor("#F1F5FA", 1.0);
    pub const BackgroundColor = hexColor("#151B24", 1.0);
    pub const BarWidth: f32 = 48.0;

    bounding_box: [4]f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) SelectorElement {
        _ = w;

        return SelectorElement{
            .bounding_box = .{ x, y, BarWidth, h },
        };
    }

    pub fn generate_quad_instances(self: SelectorElement, quads: []QuadInstance) usize {
        quads[0] = .{
            .color = SelectorElement.BackgroundColor,
            .shape = self.bounding_box,
        };

        return 1;
    }
};

pub const InspectorElement = struct {
    pub const TextColor = hexColor("#F1F5FA", 1.0);
    pub const BackgroundColor = hexColor("#151B24", 1.0);
    pub const BarWidth: f32 = 48.0;

    bounding_box: [4]f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) InspectorElement {
        _ = w;

        return InspectorElement{
            .bounding_box = .{ x, y, BarWidth, h },
        };
    }

    pub fn generate_quad_instances(self: InspectorElement, quads: []QuadInstance) usize {
        quads[0] = .{
            .color = InspectorElement.BackgroundColor,
            .shape = self.bounding_box,
        };

        return 1;
    }
};

pub const StatusElement = struct {
    pub const TextColor = hexColor("#9EACBE", 1.0);
    pub const BackgroundColor = hexColor("#202A38", 1.0);
    pub const BarHeight: f32 = 24.0;

    bounding_box: [4]f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) StatusElement {
        _ = h;

        return StatusElement{
            .bounding_box = .{ x, y, w, BarHeight },
        };
    }

    pub fn generate_quad_instances(self: StatusElement, quads: []QuadInstance) usize {
        quads[0] = .{
            .color = StatusElement.BackgroundColor,
            .shape = self.bounding_box,
        };

        return 1;
    }
};

pub const ConsoleElement = struct {
    pub const TextColor = hexColor("#F1F5FA", 1.0);
    pub const BackgroundColor = hexColor("#171E29", 1.0);
    pub const BarHeight: f32 = 120.0;

    bounding_box: [4]f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) ConsoleElement {
        _ = h;

        return ConsoleElement{
            .bounding_box = .{ x, y, w, BarHeight },
        };
    }

    pub fn generate_quad_instances(self: ConsoleElement, quads: []QuadInstance) usize {
        quads[0] = .{
            .color = BackgroundColor,
            .shape = self.bounding_box,
        };

        return 1;
    }
};

/// Our error set for SDL3
pub const SDL3Error = error{
    LibraryInitialization,
    UnexpectedNullPointer,
    WindowInitialization,
    GPUInitialization,
    GPUInteraction,
};

/// Ways of using SDL3 buffers
pub const SDL3BufferUsage = enum(u32) {
    VERTEX = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
    INDEX = sdl.SDL_GPU_BUFFERUSAGE_INDEX,
    GRAPHICS_STORAGE_READ = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
};

/// Ergonomic wrapper to specify the SDL3 shader backend
pub const SDL3ShaderFormat = enum(u32) {
    spirv = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
    dxbc = sdl.SDL_GPU_SHADERFORMAT_DXBC,
    dxil = sdl.SDL_GPU_SHADERFORMAT_DXIL,
    msl = sdl.SDL_GPU_SHADERFORMAT_MSL,
    metal = sdl.SDL_GPU_SHADERFORMAT_METALLIB,
};

/// Ergonomic wrapper to capture SDL events
const SDL3EventEnum = enum(u32) {
    SDL_EVENT_QUIT = sdl.SDL_EVENT_QUIT,
    SDL_EVENT_TERMINATING = sdl.SDL_EVENT_TERMINATING,
    SDL_EVENT_LOW_MEMORY = sdl.SDL_EVENT_LOW_MEMORY,
    SDL_EVENT_WILL_ENTER_BACKGROUND = sdl.SDL_EVENT_WILL_ENTER_BACKGROUND,
    SDL_EVENT_DID_ENTER_BACKGROUND = sdl.SDL_EVENT_DID_ENTER_BACKGROUND,
    SDL_EVENT_WILL_ENTER_FOREGROUND = sdl.SDL_EVENT_WILL_ENTER_FOREGROUND,
    SDL_EVENT_DID_ENTER_FOREGROUND = sdl.SDL_EVENT_DID_ENTER_FOREGROUND,
    SDL_EVENT_LOCALE_CHANGED = sdl.SDL_EVENT_LOCALE_CHANGED,
    SDL_EVENT_SYSTEM_THEME_CHANGED = sdl.SDL_EVENT_SYSTEM_THEME_CHANGED,
    SDL_EVENT_DISPLAY_ORIENTATION = sdl.SDL_EVENT_DISPLAY_ORIENTATION,
    SDL_EVENT_DISPLAY_ADDED = sdl.SDL_EVENT_DISPLAY_ADDED,
    SDL_EVENT_DISPLAY_REMOVED = sdl.SDL_EVENT_DISPLAY_REMOVED,
    SDL_EVENT_DISPLAY_MOVED = sdl.SDL_EVENT_DISPLAY_MOVED,
    SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED = sdl.SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED,
    SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED = sdl.SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED,
    SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED = sdl.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED,
    SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED = sdl.SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED,
    SDL_EVENT_WINDOW_SHOWN = sdl.SDL_EVENT_WINDOW_SHOWN,
    SDL_EVENT_WINDOW_HIDDEN = sdl.SDL_EVENT_WINDOW_HIDDEN,
    SDL_EVENT_WINDOW_EXPOSED = sdl.SDL_EVENT_WINDOW_EXPOSED,
    SDL_EVENT_WINDOW_MOVED = sdl.SDL_EVENT_WINDOW_MOVED,
    SDL_EVENT_WINDOW_RESIZED = sdl.SDL_EVENT_WINDOW_RESIZED,
    SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED = sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
    SDL_EVENT_WINDOW_METAL_VIEW_RESIZED = sdl.SDL_EVENT_WINDOW_METAL_VIEW_RESIZED,
    SDL_EVENT_WINDOW_MINIMIZED = sdl.SDL_EVENT_WINDOW_MINIMIZED,
    SDL_EVENT_WINDOW_MAXIMIZED = sdl.SDL_EVENT_WINDOW_MAXIMIZED,
    SDL_EVENT_WINDOW_RESTORED = sdl.SDL_EVENT_WINDOW_RESTORED,
    SDL_EVENT_WINDOW_MOUSE_ENTER = sdl.SDL_EVENT_WINDOW_MOUSE_ENTER,
    SDL_EVENT_WINDOW_MOUSE_LEAVE = sdl.SDL_EVENT_WINDOW_MOUSE_LEAVE,
    SDL_EVENT_WINDOW_FOCUS_GAINED = sdl.SDL_EVENT_WINDOW_FOCUS_GAINED,
    SDL_EVENT_WINDOW_FOCUS_LOST = sdl.SDL_EVENT_WINDOW_FOCUS_LOST,
    SDL_EVENT_WINDOW_CLOSE_REQUESTED = sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
    SDL_EVENT_WINDOW_HIT_TEST = sdl.SDL_EVENT_WINDOW_HIT_TEST,
    SDL_EVENT_WINDOW_ICCPROF_CHANGED = sdl.SDL_EVENT_WINDOW_ICCPROF_CHANGED,
    SDL_EVENT_WINDOW_DISPLAY_CHANGED = sdl.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
    SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED = sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
    SDL_EVENT_WINDOW_SAFE_AREA_CHANGED = sdl.SDL_EVENT_WINDOW_SAFE_AREA_CHANGED,
    SDL_EVENT_WINDOW_OCCLUDED = sdl.SDL_EVENT_WINDOW_OCCLUDED,
    SDL_EVENT_WINDOW_ENTER_FULLSCREEN = sdl.SDL_EVENT_WINDOW_ENTER_FULLSCREEN,
    SDL_EVENT_WINDOW_LEAVE_FULLSCREEN = sdl.SDL_EVENT_WINDOW_LEAVE_FULLSCREEN,
    SDL_EVENT_WINDOW_DESTROYED = sdl.SDL_EVENT_WINDOW_DESTROYED,
    SDL_EVENT_WINDOW_HDR_STATE_CHANGED = sdl.SDL_EVENT_WINDOW_HDR_STATE_CHANGED,
    SDL_EVENT_KEY_DOWN = sdl.SDL_EVENT_KEY_DOWN,
    SDL_EVENT_KEY_UP = sdl.SDL_EVENT_KEY_UP,
    SDL_EVENT_TEXT_EDITING = sdl.SDL_EVENT_TEXT_EDITING,
    SDL_EVENT_TEXT_INPUT = sdl.SDL_EVENT_TEXT_INPUT,
    SDL_EVENT_KEYMAP_CHANGED = sdl.SDL_EVENT_KEYMAP_CHANGED,
    SDL_EVENT_KEYBOARD_ADDED = sdl.SDL_EVENT_KEYBOARD_ADDED,
    SDL_EVENT_KEYBOARD_REMOVED = sdl.SDL_EVENT_KEYBOARD_REMOVED,
    SDL_EVENT_TEXT_EDITING_CANDIDATES = sdl.SDL_EVENT_TEXT_EDITING_CANDIDATES,
    SDL_EVENT_SCREEN_KEYBOARD_SHOWN = sdl.SDL_EVENT_SCREEN_KEYBOARD_SHOWN,
    SDL_EVENT_SCREEN_KEYBOARD_HIDDEN = sdl.SDL_EVENT_SCREEN_KEYBOARD_HIDDEN,
    SDL_EVENT_MOUSE_MOTION = sdl.SDL_EVENT_MOUSE_MOTION,
    SDL_EVENT_MOUSE_BUTTON_DOWN = sdl.SDL_EVENT_MOUSE_BUTTON_DOWN,
    SDL_EVENT_MOUSE_BUTTON_UP = sdl.SDL_EVENT_MOUSE_BUTTON_UP,
    SDL_EVENT_MOUSE_WHEEL = sdl.SDL_EVENT_MOUSE_WHEEL,
    SDL_EVENT_MOUSE_ADDED = sdl.SDL_EVENT_MOUSE_ADDED,
    SDL_EVENT_MOUSE_REMOVED = sdl.SDL_EVENT_MOUSE_REMOVED,
    SDL_EVENT_JOYSTICK_AXIS_MOTION = sdl.SDL_EVENT_JOYSTICK_AXIS_MOTION,
    SDL_EVENT_JOYSTICK_BALL_MOTION = sdl.SDL_EVENT_JOYSTICK_BALL_MOTION,
    SDL_EVENT_JOYSTICK_HAT_MOTION = sdl.SDL_EVENT_JOYSTICK_HAT_MOTION,
    SDL_EVENT_JOYSTICK_BUTTON_DOWN = sdl.SDL_EVENT_JOYSTICK_BUTTON_DOWN,
    SDL_EVENT_JOYSTICK_BUTTON_UP = sdl.SDL_EVENT_JOYSTICK_BUTTON_UP,
    SDL_EVENT_JOYSTICK_ADDED = sdl.SDL_EVENT_JOYSTICK_ADDED,
    SDL_EVENT_JOYSTICK_REMOVED = sdl.SDL_EVENT_JOYSTICK_REMOVED,
    SDL_EVENT_JOYSTICK_BATTERY_UPDATED = sdl.SDL_EVENT_JOYSTICK_BATTERY_UPDATED,
    SDL_EVENT_JOYSTICK_UPDATE_COMPLETE = sdl.SDL_EVENT_JOYSTICK_UPDATE_COMPLETE,
    SDL_EVENT_GAMEPAD_AXIS_MOTION = sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION,
    SDL_EVENT_GAMEPAD_BUTTON_DOWN = sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN,
    SDL_EVENT_GAMEPAD_BUTTON_UP = sdl.SDL_EVENT_GAMEPAD_BUTTON_UP,
    SDL_EVENT_GAMEPAD_ADDED = sdl.SDL_EVENT_GAMEPAD_ADDED,
    SDL_EVENT_GAMEPAD_REMOVED = sdl.SDL_EVENT_GAMEPAD_REMOVED,
    SDL_EVENT_GAMEPAD_REMAPPED = sdl.SDL_EVENT_GAMEPAD_REMAPPED,
    SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN,
    SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION,
    SDL_EVENT_GAMEPAD_TOUCHPAD_UP = sdl.SDL_EVENT_GAMEPAD_TOUCHPAD_UP,
    SDL_EVENT_GAMEPAD_SENSOR_UPDATE = sdl.SDL_EVENT_GAMEPAD_SENSOR_UPDATE,
    SDL_EVENT_GAMEPAD_UPDATE_COMPLETE = sdl.SDL_EVENT_GAMEPAD_UPDATE_COMPLETE,
    SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED = sdl.SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED,
    SDL_EVENT_FINGER_DOWN = sdl.SDL_EVENT_FINGER_DOWN,
    SDL_EVENT_FINGER_UP = sdl.SDL_EVENT_FINGER_UP,
    SDL_EVENT_FINGER_MOTION = sdl.SDL_EVENT_FINGER_MOTION,
    SDL_EVENT_FINGER_CANCELED = sdl.SDL_EVENT_FINGER_CANCELED,
    SDL_EVENT_PINCH_BEGIN = sdl.SDL_EVENT_PINCH_BEGIN,
    SDL_EVENT_PINCH_UPDATE = sdl.SDL_EVENT_PINCH_UPDATE,
    SDL_EVENT_PINCH_END = sdl.SDL_EVENT_PINCH_END,
    SDL_EVENT_CLIPBOARD_UPDATE = sdl.SDL_EVENT_CLIPBOARD_UPDATE,
    SDL_EVENT_DROP_FILE = sdl.SDL_EVENT_DROP_FILE,
    SDL_EVENT_DROP_TEXT = sdl.SDL_EVENT_DROP_TEXT,
    SDL_EVENT_DROP_BEGIN = sdl.SDL_EVENT_DROP_BEGIN,
    SDL_EVENT_DROP_COMPLETE = sdl.SDL_EVENT_DROP_COMPLETE,
    SDL_EVENT_DROP_POSITION = sdl.SDL_EVENT_DROP_POSITION,
    SDL_EVENT_AUDIO_DEVICE_ADDED = sdl.SDL_EVENT_AUDIO_DEVICE_ADDED,
    SDL_EVENT_AUDIO_DEVICE_REMOVED = sdl.SDL_EVENT_AUDIO_DEVICE_REMOVED,
    SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED = sdl.SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED,
    SDL_EVENT_SENSOR_UPDATE = sdl.SDL_EVENT_SENSOR_UPDATE,
    SDL_EVENT_PEN_PROXIMITY_IN = sdl.SDL_EVENT_PEN_PROXIMITY_IN,
    SDL_EVENT_PEN_PROXIMITY_OUT = sdl.SDL_EVENT_PEN_PROXIMITY_OUT,
    SDL_EVENT_PEN_DOWN = sdl.SDL_EVENT_PEN_DOWN,
    SDL_EVENT_PEN_UP = sdl.SDL_EVENT_PEN_UP,
    SDL_EVENT_PEN_BUTTON_DOWN = sdl.SDL_EVENT_PEN_BUTTON_DOWN,
    SDL_EVENT_PEN_BUTTON_UP = sdl.SDL_EVENT_PEN_BUTTON_UP,
    SDL_EVENT_PEN_MOTION = sdl.SDL_EVENT_PEN_MOTION,
    SDL_EVENT_PEN_AXIS = sdl.SDL_EVENT_PEN_AXIS,
    SDL_EVENT_CAMERA_DEVICE_ADDED = sdl.SDL_EVENT_CAMERA_DEVICE_ADDED,
    SDL_EVENT_CAMERA_DEVICE_REMOVED = sdl.SDL_EVENT_CAMERA_DEVICE_REMOVED,
    SDL_EVENT_CAMERA_DEVICE_APPROVED = sdl.SDL_EVENT_CAMERA_DEVICE_APPROVED,
    SDL_EVENT_CAMERA_DEVICE_DENIED = sdl.SDL_EVENT_CAMERA_DEVICE_DENIED,
    SDL_EVENT_RENDER_TARGETS_RESET = sdl.SDL_EVENT_RENDER_TARGETS_RESET,
    SDL_EVENT_RENDER_DEVICE_RESET = sdl.SDL_EVENT_RENDER_DEVICE_RESET,
    SDL_EVENT_RENDER_DEVICE_LOST = sdl.SDL_EVENT_RENDER_DEVICE_LOST,
    SDL_EVENT_PRIVATE0 = sdl.SDL_EVENT_PRIVATE0,
    SDL_EVENT_PRIVATE1 = sdl.SDL_EVENT_PRIVATE1,
    SDL_EVENT_PRIVATE2 = sdl.SDL_EVENT_PRIVATE2,
    SDL_EVENT_PRIVATE3 = sdl.SDL_EVENT_PRIVATE3,
    SDL_EVENT_POLL_SENTINEL = sdl.SDL_EVENT_POLL_SENTINEL,
    _,
};

/// Complete set of settings specifying the behaviour of the app
pub const ProgramSettings = struct {
    shader_format: SDL3ShaderFormat,
    enable_gpu_debug: bool,
    window_w: u32,
    window_h: u32,
};

/// Helper struct typing dimensions to an SDL swapchain texture
const SwapchainTexture = struct {
    tex: *sdl.SDL_GPUTexture,
    w: u32,
    h: u32,
};

/// Name of our window
const WindowName: [*:0]const u8 = "vibe-patcher";

/// Our default clear color
const ClearColorHex = hexColor("#D9DEE5", 1.0);
const ClearColor: sdl.SDL_FColor = @bitCast(ClearColorHex);

/// Initialize the SDL3 library with the specified subsystems
fn SDL3Initialize() SDL3Error!void {
    std.log.info("Initializing SDL3 backend...", .{});
    errdefer std.log.err("Initializing SDL3 backend failed: '{s}'", .{sdl.SDL_GetError()});

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO)) {
        return SDL3Error.LibraryInitialization;
    }

    std.log.info("Initializing SDL3 backend OK", .{});
}

/// Clean up the specified SDL3 subsystems
fn SDL3Quit() void {
    std.log.info("Destroying SDL3 subsystems", .{});
    sdl.SDL_Quit();
}

/// Create an SDL3 GPU context
fn SDL3CreateGPUDevice(shader_format: SDL3ShaderFormat, debug: bool) SDL3Error!*sdl.SDL_GPUDevice {
    std.log.info("Creating SDL3 GPU device...", .{});
    errdefer std.log.err("Creating SDL3 GPU device failed: '{s}'", .{sdl.SDL_GetError()});

    const device = sdl.SDL_CreateGPUDevice(@intFromEnum(shader_format), debug, null) orelse {
        return SDL3Error.UnexpectedNullPointer;
    };

    std.log.info("Creating SDL3 GPU device OK", .{});
    return device;
}

/// Destroy the SDL3 GPU context
fn SDL3DestroyGPUDevice(device: *sdl.SDL_GPUDevice) void {
    std.log.info("Destroying SDL3 GPU device", .{});
    sdl.SDL_DestroyGPUDevice(device);
}

/// Create an SDL3 window
fn SDL3CreateWindow(title: [*:0]const u8, w: u32, h: u32) SDL3Error!*sdl.SDL_Window {
    std.log.info("Creating SDL3 Window...", .{});
    errdefer std.log.err("Creating SDL3 GPU device failed: '{s}'", .{sdl.SDL_GetError()});

    const flags = sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY;
    const window = sdl.SDL_CreateWindow(title, @intCast(w), @intCast(h), flags) orelse {
        return SDL3Error.UnexpectedNullPointer;
    };

    std.log.info("Creating SDL3 Window OK", .{});
    return window;
}

/// Destroy the SDL3 window
fn SDL3DestroyWindow(window: *sdl.SDL_Window) void {
    std.log.info("Destroying SDL3 GPU Window", .{});
    sdl.SDL_DestroyWindow(window);
}

/// Claim the SDL3 window to the gpu
fn SDL3GPUClaimWindow(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window) SDL3Error!void {
    std.log.info("Claiming SDL3 window for our GPU...", .{});
    errdefer std.log.err("Claiming SDL3 window for our GPU failed: '{s}'", .{sdl.SDL_GetError()});

    if (sdl.SDL_ClaimWindowForGPUDevice(device, window) != true) {
        return SDL3Error.GPUInitialization;
    }

    std.log.info("Claiming SDL3 window for our GPU OK", .{});
}

/// Claim the SDL3 window from the GPU
fn SDL3GPUDestroyWindow(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window) void {
    std.log.info("Destroying SDL3 window", .{});

    sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
}

/// Acquire a command buffer from an SDL3 GPU
fn SDL3AcquireGPUCommandBuffer(device: *sdl.SDL_GPUDevice) SDL3Error!*sdl.SDL_GPUCommandBuffer {
    std.log.debug("Acquiring command buffer from SDL3 GPU", .{});
    errdefer std.log.err("Acquiring command buffer from SDL3 GPU failed: '{s}'", .{sdl.SDL_GetError()});

    const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.debug("Acquiring command buffer from SDL3 GPU OK", .{});
    return command_buffer;
}

/// Submit a command buffer to the SDL3 GPU
fn SDL3SubmitGPUCommandBuffer(command_buffer: *sdl.SDL_GPUCommandBuffer) SDL3Error!void {
    const str = "Submitting command buffer to SDL3 GPU";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    if (!sdl.SDL_SubmitGPUCommandBuffer(command_buffer)) {
        return SDL3Error.GPUInteraction;
    }

    std.log.debug("{s} OK", .{str});
}

fn SDL3GPUColorTargetInfos(texture: *sdl.SDL_GPUTexture) [1]sdl.SDL_GPUColorTargetInfo {
    return .{
        .{
            .texture = texture,
            .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
            .store_op = sdl.SDL_GPU_STOREOP_STORE,
            .clear_color = ClearColor,
            .mip_level = 0,
            .resolve_mip_level = 0,
            .cycle = false,
            .resolve_layer = 0,
            .resolve_texture = null,
            .cycle_resolve_texture = false,
            .layer_or_depth_plane = 0,
        },
    };
}

/// Begin a SDL3 GPU render pass
fn SDL3BeginGPURenderPass(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    color_target_infos: []const sdl.SDL_GPUColorTargetInfo,
    depth_stencil_target_info: ?*sdl.SDL_GPUDepthStencilTargetInfo,
) SDL3Error!*sdl.SDL_GPURenderPass {
    const str = "Beginning SDL3 GPU render pass";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const render_pass = sdl.SDL_BeginGPURenderPass(
        command_buffer,
        color_target_infos.ptr,
        @intCast(color_target_infos.len),
        depth_stencil_target_info,
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.debug("{s} OK", .{str});
    return render_pass;
}

/// End a SDL3 GPU render pass
fn SDL3EndGPURenderPass(
    render_pass: *sdl.SDL_GPURenderPass,
) void {
    const str = "Ending SDL3 GPU render pass";
    std.log.debug("{s}", .{str});

    sdl.SDL_EndGPURenderPass(render_pass);
}

/// Block until we can acquire a swapchain texture. Blocking dictated by vsync.
fn SDL3AcquireGPUSwapchainTextureBlocking(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    window: *sdl.SDL_Window,
) SDL3Error!?SwapchainTexture {
    const str = "Acquiring SDL3 GPU swapchain texture";
    std.log.debug("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    var w: u32 = 0;
    var h: u32 = 0;
    var texture: ?*sdl.SDL_GPUTexture = null;
    if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        window,
        &texture,
        &w,
        &h,
    )) {
        return SDL3Error.GPUInteraction;
    }

    if (texture) |tex| {
        std.log.debug("{s} OK", .{str});
        return SwapchainTexture{
            .tex = tex,
            .w = w,
            .h = h,
        };
    } else {
        std.log.info("{s} resulted in null texture, app possibly minimized", .{str});
        return null;
    }
}

/// Helper function to print an SDL3 Event
fn SDL3EventName(event: u32) []const u8 {
    return switch (@as(SDL3EventEnum, @enumFromInt(event))) {
        _ => "SDL_EVENT_UNKNOWN",
        inline else => |tag| @tagName(tag),
    };
}

/// Polls for an SDL3 event
fn SDL3PollEvent() ?sdl.SDL_Event {
    var event = std.mem.zeroes(sdl.SDL_Event);
    if (sdl.SDL_PollEvent(&event)) {
        std.log.info("Got SDL3 event with type '{s}'", .{SDL3EventName(event.type)});
        return event;
    }

    return null;
}

/// Load a SDL3 GPU shader from bytecode
fn SDL3GPUCreateShader(device: *sdl.SDL_GPUDevice, shader: shader_module.Shader) SDL3Error!*sdl.SDL_GPUShader {
    const str = "Creating SDL3 GPU shader";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const sdl_shader = sdl.SDL_CreateGPUShader(
        device,
        &sdl.SDL_GPUShaderCreateInfo{
            .code_size = shader.code.len,
            .code = shader.code.ptr,
            .entrypoint = "main",
            .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            .num_samplers = shader.num_samplers,
            .num_storage_buffers = shader.num_storage_buffers,
            .num_uniform_buffers = shader.num_uniform_buffers,
            .num_storage_textures = shader.num_storage_textures,
            .stage = switch (shader.kind) {
                .FRAG => sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
                .VERT => sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            },
        },
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return sdl_shader;
}

/// Destroy a SDL3 GPU shader
fn SDL3GPUDestroyShader(device: *sdl.SDL_GPUDevice, shader: *sdl.SDL_GPUShader) void {
    std.log.info("Destroying SDL3 shader", .{});

    sdl.SDL_ReleaseGPUShader(device, shader);
}

/// Create an SDL3 graphics pipeline
fn SDL3GPUCreateGraphicsPipeline(
    device: *sdl.SDL_GPUDevice,
    window: *sdl.SDL_Window,
    vert: *sdl.SDL_GPUShader,
    frag: *sdl.SDL_GPUShader,
    vertex_input_state: sdl.SDL_GPUVertexInputState,
    blend: bool,
) SDL3Error!*sdl.SDL_GPUGraphicsPipeline {
    const str = "Creating SDL3 GPU graphics pipeline";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const blend_state = if (blend) sdl.SDL_GPUColorTargetBlendState{
        .enable_blend = true,
        .src_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
        .dst_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        .color_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
        .src_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE,
        .dst_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
        .alpha_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
        .color_write_mask = 0xF,
        .enable_color_write_mask = false,
    } else std.mem.zeroes(sdl.SDL_GPUColorTargetBlendState);

    const color_targets = [_]sdl.SDL_GPUColorTargetDescription{
        sdl.SDL_GPUColorTargetDescription{
            .format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
            .blend_state = blend_state,
        },
    };

    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(
        device,
        &sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = vert,
            .fragment_shader = frag,
            .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLESTRIP,
            .target_info = sdl.SDL_GPUGraphicsPipelineTargetInfo{
                .num_color_targets = 1,
                .color_target_descriptions = &color_targets,

                // Remaining
                .depth_stencil_format = 0,
                .has_depth_stencil_target = false,
            },
            .rasterizer_state = sdl.SDL_GPURasterizerState{
                .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
                .cull_mode = sdl.SDL_GPU_CULLMODE_NONE,

                // Remaining
                .depth_bias_clamp = 0,
                .depth_bias_constant_factor = 0,
                .depth_bias_slope_factor = 0,
                .enable_depth_bias = false,
                .enable_depth_clip = false,
                .front_face = 0,
            },
            .multisample_state = std.mem.zeroes(sdl.SDL_GPUMultisampleState), // NOTE: disables it
            .vertex_input_state = vertex_input_state,

            // Remaining
            .depth_stencil_state = std.mem.zeroes(sdl.SDL_GPUDepthStencilState),
            .props = 0,
        },
    ) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return pipeline;
}

/// Destroy an SDL3 graphics pipeline
fn SDL3GPUDestroyGraphicsPipeline(device: *sdl.SDL_GPUDevice, pipeline: *sdl.SDL_GPUGraphicsPipeline) void {
    std.log.info("Destroying SDL3 graphics pipeline", .{});

    sdl.SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
}

/// Bind an SDL3 pipeline to a render pass
fn SDL3GPUBindPipeline(render_pass: *sdl.SDL_GPURenderPass, pipeline: *sdl.SDL_GPUGraphicsPipeline) void {
    std.log.debug("Binding SDL3 GPU graphics pipeline", .{});

    sdl.SDL_BindGPUGraphicsPipeline(render_pass, pipeline);
}

/// Bind a number of SDL3 vertex buffers to a render pass
fn SDL3GPUBindVertexBuffers(
    render_pass: *sdl.SDL_GPURenderPass,
    buffers: anytype,
) void {
    std.log.debug("Binding SDL3 GPU vertex buffers", .{});

    var bindings: [buffers.len]sdl.SDL_GPUBufferBinding = undefined;
    inline for (buffers, 0..) |buf, i| {
        bindings[i] = .{ .buffer = buf, .offset = 0 };
    }

    sdl.SDL_BindGPUVertexBuffers(render_pass, 0, &bindings, buffers.len);
}

fn SDL3GPUBindFragmentSampler(
    render_pass: *sdl.SDL_GPURenderPass,
    texture: *sdl.SDL_GPUTexture,
    sampler: *sdl.SDL_GPUSampler,
) void {
    std.log.debug("Binding SDL3 GPU fragment sampler", .{});

    sdl.SDL_BindGPUFragmentSamplers(render_pass, 0, &sdl.SDL_GPUTextureSamplerBinding{
        .texture = texture,
        .sampler = sampler,
    }, 1);
}

/// Bind storage buffers to a render pass for the vertex stage, starting at slot 0
fn SDL3GPUBindVertexStorageBuffers(
    render_pass: *sdl.SDL_GPURenderPass,
    buffers: anytype,
) void {
    std.log.debug("Binding SDL3 GPU vertex storage buffers", .{});

    var bufs: [buffers.len]?*sdl.SDL_GPUBuffer = undefined;
    inline for (buffers, 0..) |buf, i| {
        bufs[i] = buf;
    }

    sdl.SDL_BindGPUVertexStorageBuffers(render_pass, 0, &bufs, buffers.len);
}

/// Push raw bytes to a vertex uniform slot on an SDL3 GPU command buffer.
fn SDL3GPUPushVertexUniformData(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    slot: u32,
    bytes: []const u8,
) void {
    std.log.debug("Pushing SDL3 GPU vertex uniform data", .{});

    sdl.SDL_PushGPUVertexUniformData(
        command_buffer,
        slot,
        bytes.ptr,
        @intCast(bytes.len),
    );
}

/// Push raw bytes to a fragment uniform slot on an SDL3 GPU command buffer.
fn SDL3GPUPushFragmentUniformData(
    command_buffer: *sdl.SDL_GPUCommandBuffer,
    slot: u32,
    bytes: []const u8,
) void {
    std.log.debug("Pushing SDL3 GPU fragment uniform data", .{});

    sdl.SDL_PushGPUFragmentUniformData(
        command_buffer,
        slot,
        bytes.ptr,
        @intCast(bytes.len),
    );
}

/// Bind SDL3 index buffer to a render pass, I hardcode indices to be 16 bit
fn SDL3GPUBindIndexBuffer(
    render_pass: *sdl.SDL_GPURenderPass,
    buffer: *sdl.SDL_GPUBuffer,
) void {
    std.log.debug("Binding SDL3 GPU index buffer", .{});

    sdl.SDL_BindGPUIndexBuffer(
        render_pass,
        &sdl.SDL_GPUBufferBinding{ .buffer = buffer, .offset = 0 },
        sdl.SDL_GPU_INDEXELEMENTSIZE_16BIT,
    );
}

/// Draw primitives non-indexed: `num_vertices` per instance, `num_instances` total.
///
/// NOTE: We start at the beginning of the list in both cases.
fn SDL3GPUDraw(
    render_pass: *sdl.SDL_GPURenderPass,
    num_vertices: usize,
    num_instances: usize,
) void {
    std.log.debug("Drawing on SDL3 GPU", .{});

    sdl.SDL_DrawGPUPrimitives(render_pass, @intCast(num_vertices), @intCast(num_instances), 0, 0);
}

/// Create an SDL3 GPU buffer
fn SDL3GPUCreateBuffer(
    device: *sdl.SDL_GPUDevice,
    usage: SDL3BufferUsage,
    size: u32,
) SDL3Error!*sdl.SDL_GPUBuffer {
    const str = "Creating SDL3 GPU buffer";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const buffer = sdl.SDL_CreateGPUBuffer(device, &sdl.SDL_GPUBufferCreateInfo{
        .size = size,
        .usage = @intFromEnum(usage),

        // Remaining
        .props = 0,
    }) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return buffer;
}

/// Destroy an SDL3 GPU buffer
fn SDL3GPUDestroyBuffer(device: *sdl.SDL_GPUDevice, buffer: *sdl.SDL_GPUBuffer) void {
    std.log.info("Destroying SDL3 buffer", .{});

    sdl.SDL_ReleaseGPUBuffer(device, buffer);
}

/// Upload buffer to SDL3 GPU
fn SDL3GPUBufferUpload(
    device: *sdl.SDL_GPUDevice,
    target: *sdl.SDL_GPUBuffer,
    bytes: []const u8,
) SDL3Error!void {
    const str = "Uploading to SDL3 GPU buffer";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const transfer = sdl.SDL_CreateGPUTransferBuffer(
        device,
        &sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = @intCast(bytes.len),
            .props = 0,
        },
    ) orelse {
        return SDL3Error.GPUInteraction;
    };
    defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer);

    {
        const mapped = sdl.SDL_MapGPUTransferBuffer(device, transfer, false) orelse {
            return SDL3Error.GPUInteraction;
        };
        defer sdl.SDL_UnmapGPUTransferBuffer(device, transfer);

        @memcpy(@as([*]u8, @ptrCast(mapped))[0..bytes.len], bytes);
    }

    {
        const cmd = try SDL3AcquireGPUCommandBuffer(device);
        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse return SDL3Error.GPUInteraction;
        sdl.SDL_UploadToGPUBuffer(
            copy_pass,
            &sdl.SDL_GPUTransferBufferLocation{ .transfer_buffer = transfer, .offset = 0 },
            &sdl.SDL_GPUBufferRegion{ .buffer = target, .offset = 0, .size = @intCast(bytes.len) },
            false,
        );
        sdl.SDL_EndGPUCopyPass(copy_pass);
        try SDL3SubmitGPUCommandBuffer(cmd);
    }

    std.log.info("{s} OK", .{str});
}

/// Create a texture to be used with glyphs
fn SDL3GPUCreateTextureGlyph(device: *sdl.SDL_GPUDevice, w: u32, h: u32) SDL3Error!*sdl.SDL_GPUTexture {
    const str = "Creating SDL3 GPU texture to be used with glyphs";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const texture = sdl.SDL_CreateGPUTexture(device, &sdl.SDL_GPUTextureCreateInfo{
        .type = sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = w,
        .height = h,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
        .props = 0,
    }) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return texture;
}

/// Create a texture to be used with glyphs
fn SDL3GPUDestroyTexture(device: *sdl.SDL_GPUDevice, texture: *sdl.SDL_GPUTexture) void {
    std.log.info("Destroying SDL3 texture", .{});

    sdl.SDL_ReleaseGPUTexture(device, texture);
}

fn SDL3GPUTextureUpload(
    device: *sdl.SDL_GPUDevice,
    target: *sdl.SDL_GPUTexture,
    w: u32,
    h: u32,
    bytes: []const u8, // tightly packed RGBA8, len == w*h*4
) SDL3Error!void {
    const str = "Uploading to SDL3 GPU texture";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const transfer = sdl.SDL_CreateGPUTransferBuffer(device, &sdl.SDL_GPUTransferBufferCreateInfo{
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = @intCast(bytes.len),
        .props = 0,
    }) orelse return SDL3Error.GPUInteraction;
    defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer);

    {
        const mapped = sdl.SDL_MapGPUTransferBuffer(device, transfer, false) orelse
            return SDL3Error.GPUInteraction;
        defer sdl.SDL_UnmapGPUTransferBuffer(device, transfer);
        @memcpy(@as([*]u8, @ptrCast(mapped))[0..bytes.len], bytes);
    }
    {
        const cmd = try SDL3AcquireGPUCommandBuffer(device);
        const copy_pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse return SDL3Error.GPUInteraction;
        sdl.SDL_UploadToGPUTexture(
            copy_pass,
            &sdl.SDL_GPUTextureTransferInfo{
                .transfer_buffer = transfer,
                .offset = 0,
                .pixels_per_row = w,
                .rows_per_layer = h,
            },
            &sdl.SDL_GPUTextureRegion{
                .texture = target,
                .mip_level = 0,
                .layer = 0,
                .x = 0,
                .y = 0,
                .z = 0,
                .w = w,
                .h = h,
                .d = 1,
            },
            false,
        );
        sdl.SDL_EndGPUCopyPass(copy_pass);
        try SDL3SubmitGPUCommandBuffer(cmd);
    }

    std.log.info("{s} OK", .{str});
}

/// Create an SDL3 GPU sampler for the glyph atlas.
fn SDL3GPUCreateSamplerGlyph(device: *sdl.SDL_GPUDevice) SDL3Error!*sdl.SDL_GPUSampler {
    const str = "Creating SDL3 GPU sampler for glyphs";
    std.log.info("{s}...", .{str});
    errdefer std.log.err("{s} failed: '{s}'", .{ str, sdl.SDL_GetError() });

    const sampler = sdl.SDL_CreateGPUSampler(device, &sdl.SDL_GPUSamplerCreateInfo{
        .min_filter = sdl.SDL_GPU_FILTER_LINEAR,
        .mag_filter = sdl.SDL_GPU_FILTER_LINEAR,
        .mipmap_mode = sdl.SDL_GPU_SAMPLERMIPMAPMODE_LINEAR,
        .address_mode_u = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        .address_mode_v = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        .address_mode_w = sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,

        // Remaining
        .mip_lod_bias = 0,
        .max_anisotropy = 0,
        .compare_op = 0,
        .min_lod = 0,
        .max_lod = 0,
        .enable_anisotropy = false,
        .enable_compare = false,
        .props = 0,
    }) orelse {
        return SDL3Error.GPUInteraction;
    };

    std.log.info("{s} OK", .{str});
    return sampler;
}

/// Helper to set the viewport of our renderpass
fn SDL3GPUSetViewport(
    render_pass: *sdl.SDL_GPURenderPass,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) void {
    const viewport = sdl.SDL_GPUViewport{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
        .min_depth = 0.0,
        .max_depth = 1.0,
    };

    sdl.SDL_SetGPUViewport(render_pass, &viewport);
}

/// Helper to set the scissor of our renderpass
fn SDL3GPUSetScissor(
    render_pass: *sdl.SDL_GPURenderPass,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) void {
    const rect = sdl.SDL_Rect{
        .x = @intFromFloat(x),
        .y = @intFromFloat(y),
        .w = @intFromFloat(w),
        .h = @intFromFloat(h),
    };

    sdl.SDL_SetGPUScissor(render_pass, &rect);
}

/// Destroy an SDL3 GPU sampler
fn SDL3GPUDestroySampler(device: *sdl.SDL_GPUDevice, sampler: *sdl.SDL_GPUSampler) void {
    std.log.info("Destroying SDL3 sampler", .{});

    sdl.SDL_ReleaseGPUSampler(device, sampler);
}

/// Main entrypoint into the program
pub fn run(settings: ProgramSettings) SDL3Error!void {
    var interface = UserInterface.init(@floatFromInt(settings.window_w), @floatFromInt(settings.window_h));

    // Setup device + windowing
    try SDL3Initialize();
    defer SDL3Quit();

    const device = try SDL3CreateGPUDevice(settings.shader_format, settings.enable_gpu_debug);
    defer SDL3DestroyGPUDevice(device);

    const window = try SDL3CreateWindow(WindowName, settings.window_w, settings.window_h);
    defer SDL3DestroyWindow(window);

    try SDL3GPUClaimWindow(device, window);
    defer SDL3GPUDestroyWindow(device, window);

    // Setup canvas pipeline
    const canvas_vert = try SDL3GPUCreateShader(device, CanvasVert);
    defer SDL3GPUDestroyShader(device, canvas_vert);

    const canvas_frag = try SDL3GPUCreateShader(device, CanvasFrag);
    defer SDL3GPUDestroyShader(device, canvas_frag);

    const canvas_pipeline = try SDL3GPUCreateGraphicsPipeline(
        device,
        window,
        canvas_vert,
        canvas_frag,
        std.mem.zeroes(sdl.SDL_GPUVertexInputState),
        true,
    );
    defer SDL3GPUDestroyGraphicsPipeline(device, canvas_pipeline);

    var canvas_ubo = CanvasUniform.init(interface.canvas);

    // Setup quad pipeline
    const quad_vert = try SDL3GPUCreateShader(device, QuadVert);
    defer SDL3GPUDestroyShader(device, quad_vert);

    const quad_frag = try SDL3GPUCreateShader(device, QuadFrag);
    defer SDL3GPUDestroyShader(device, quad_frag);

    const quad_pipeline = try SDL3GPUCreateGraphicsPipeline(
        device,
        window,
        quad_vert,
        quad_frag,
        std.mem.zeroes(sdl.SDL_GPUVertexInputState),
        false,
    );
    defer SDL3GPUDestroyGraphicsPipeline(device, quad_pipeline);

    const QuadCapacity = 4096;
    const quad_buffer = try SDL3GPUCreateBuffer(
        device,
        .GRAPHICS_STORAGE_READ,
        QuadCapacity * @sizeOf(QuadInstance),
    );
    defer SDL3GPUDestroyBuffer(device, quad_buffer);

    var quad_count: usize = 0;
    var quad_scratch: [QuadCapacity]QuadInstance = undefined;

    // Setup glyph pipeline
    const glyph_vert = try SDL3GPUCreateShader(device, GlyphVert);
    defer SDL3GPUDestroyShader(device, glyph_vert);

    const glyph_frag = try SDL3GPUCreateShader(device, GlyphFrag);
    defer SDL3GPUDestroyShader(device, glyph_frag);

    const default_glyph_w = DefaultFont.config.atlas.width;
    const default_glyph_h = DefaultFont.config.atlas.height;
    const default_glyph_data = DefaultFont.data;
    const default_glyph_ubo = GlyphUniform.init(font_module.FontAtlas(DefaultFont.config));

    const default_glyph_texture = try SDL3GPUCreateTextureGlyph(device, default_glyph_w, default_glyph_h);
    defer SDL3GPUDestroyTexture(device, default_glyph_texture);
    try SDL3GPUTextureUpload(device, default_glyph_texture, default_glyph_w, default_glyph_h, default_glyph_data);

    const mono_glyph_w = MonoFont.config.atlas.width;
    const mono_glyph_h = MonoFont.config.atlas.height;
    const mono_glyph_data = MonoFont.data;
    const mono_glyph_ubo = GlyphUniform.init(font_module.FontAtlas(MonoFont.config));

    const mono_glyph_texture = try SDL3GPUCreateTextureGlyph(device, mono_glyph_w, mono_glyph_h);
    defer SDL3GPUDestroyTexture(device, mono_glyph_texture);
    try SDL3GPUTextureUpload(device, mono_glyph_texture, mono_glyph_w, mono_glyph_h, mono_glyph_data);

    const default_glyph_sampler = try SDL3GPUCreateSamplerGlyph(device);
    defer SDL3GPUDestroySampler(device, default_glyph_sampler);

    const mono_glyph_sampler = try SDL3GPUCreateSamplerGlyph(device);
    defer SDL3GPUDestroySampler(device, mono_glyph_sampler);

    const glyph_pipeline = try SDL3GPUCreateGraphicsPipeline(
        device,
        window,
        glyph_vert,
        glyph_frag,
        std.mem.zeroes(sdl.SDL_GPUVertexInputState),
        true,
    );
    defer SDL3GPUDestroyGraphicsPipeline(device, glyph_pipeline);

    const GlyphCapacity = 4096;
    const default_glyph_buffer = try SDL3GPUCreateBuffer(
        device,
        .GRAPHICS_STORAGE_READ,
        GlyphCapacity * @sizeOf(GlyphInstance),
    );
    defer SDL3GPUDestroyBuffer(device, default_glyph_buffer);

    const mono_glyph_buffer = try SDL3GPUCreateBuffer(
        device,
        .GRAPHICS_STORAGE_READ,
        GlyphCapacity * @sizeOf(GlyphInstance),
    );
    defer SDL3GPUDestroyBuffer(device, mono_glyph_buffer);

    var default_glyph_count: usize = 0;
    var default_glyph_scratch: [GlyphCapacity]GlyphInstance = undefined;

    var mono_glyph_count: usize = 0;
    var mono_glyph_scratch: [GlyphCapacity]GlyphInstance = undefined;

    var should_run = true;
    while (should_run) {
        while (SDL3PollEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => {
                    should_run = false;
                },

                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    const x = event.button.x;
                    const y = event.button.y;

                    if (event.button.button == sdl.SDL_BUTTON_LEFT and interface.canvas.contains(x, y)) {
                        interface.canvas.dragging = true;
                    }
                    std.log.info("Click down at ({d}, {d})", .{ x, y });
                },

                sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const x = event.button.x;
                    const y = event.button.y;

                    if (event.button.button == sdl.SDL_BUTTON_LEFT and interface.canvas.contains(x, y)) {
                        interface.canvas.dragging = false;
                    }

                    std.log.info("Click up at ({d}, {d})", .{ x, y });
                },

                sdl.SDL_EVENT_MOUSE_WHEEL => {
                    var delta = event.wheel.y;

                    if (event.wheel.direction == sdl.SDL_MOUSEWHEEL_FLIPPED) {
                        delta = -delta;
                    }

                    const bounds = interface.canvas.bounding_box;
                    interface.canvas.camera.center_zoom(
                        .{ bounds[2] / 2, bounds[3] / 2 },
                        std.math.pow(f32, 1.1, delta),
                    );

                    interface.toolbar.zoom = interface.canvas.camera.zoom * 100;

                    interface.dirty = true;
                },

                sdl.SDL_EVENT_MOUSE_MOTION => {
                    const x = event.motion.x;
                    const y = event.motion.y;

                    if (interface.menubar.update_hover(x, y)) {
                        interface.dirty = true;
                    }

                    if (interface.canvas.contains(x, y)) {
                        const dx = event.motion.xrel;
                        const dy = event.motion.yrel;

                        if (interface.canvas.dragging) interface.canvas.camera.drag(dx, dy);

                        interface.dirty = true;
                    }
                },

                sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    if (event.window.data1 > 0 and event.window.data2 > 0) {
                        const pixel_w: u32 = @intCast(event.window.data1);
                        const pixel_h: u32 = @intCast(event.window.data2);
                        interface.resize(@floatFromInt(pixel_w), @floatFromInt(pixel_h));
                    }
                },

                sdl.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        sdl.SDLK_Q => {
                            should_run = false;
                        },
                        else => {},
                    }
                },

                else => {},
            }

            continue;
        }

        if (!should_run) break;

        const command_buffer = try SDL3AcquireGPUCommandBuffer(device);

        const swapchain_texture = try SDL3AcquireGPUSwapchainTextureBlocking(command_buffer, window) orelse {
            try SDL3SubmitGPUCommandBuffer(command_buffer);
            continue;
        };

        const projection_ubo = ProjectionMatrixUniform.screen(swapchain_texture.w, swapchain_texture.h);

        if (interface.dirty) {
            quad_count = 0;
            quad_count += interface.generate_quad_instances(quad_scratch[quad_count..]);
            try SDL3GPUBufferUpload(device, quad_buffer, std.mem.sliceAsBytes(quad_scratch[0..quad_count]));

            default_glyph_count = 0;
            default_glyph_count += interface.generate_default_glyph_instances(&default_glyph_scratch);

            mono_glyph_count = 0;
            mono_glyph_count += interface.generate_mono_glyph_instances(&mono_glyph_scratch);

            try SDL3GPUBufferUpload(device, default_glyph_buffer, std.mem.sliceAsBytes(default_glyph_scratch[0..default_glyph_count]));
            try SDL3GPUBufferUpload(device, mono_glyph_buffer, std.mem.sliceAsBytes(mono_glyph_scratch[0..mono_glyph_count]));

            canvas_ubo = CanvasUniform.init(interface.canvas);

            interface.dirty = false;
        }

        const color_target_infos = SDL3GPUColorTargetInfos(swapchain_texture.tex);
        const render_pass = try SDL3BeginGPURenderPass(command_buffer, &color_target_infos, null);

        // canvas
        {
            const w: f32 = @floatFromInt(swapchain_texture.w);
            const h: f32 = @floatFromInt(swapchain_texture.h);
            const bounds = interface.canvas.bounding_box;

            SDL3GPUBindPipeline(render_pass, canvas_pipeline);
            SDL3GPUSetViewport(render_pass, bounds[0], bounds[1], bounds[2], bounds[3]);
            SDL3GPUPushFragmentUniformData(command_buffer, 0, std.mem.asBytes(&canvas_ubo));
            SDL3GPUSetScissor(render_pass, bounds[0], bounds[1], bounds[2], bounds[3]);

            SDL3GPUDraw(render_pass, 4, 1);

            SDL3GPUSetViewport(render_pass, 0, 0, w, h);
            SDL3GPUSetScissor(render_pass, 0, 0, w, h);
        }

        // quads
        {
            SDL3GPUBindPipeline(render_pass, quad_pipeline);
            SDL3GPUPushVertexUniformData(command_buffer, 0, std.mem.asBytes(&projection_ubo));
            SDL3GPUBindVertexStorageBuffers(render_pass, .{quad_buffer});

            SDL3GPUDraw(render_pass, QuadInstance.VertexCount, quad_count);
        }

        // glyphs
        {
            SDL3GPUBindPipeline(render_pass, glyph_pipeline);
            SDL3GPUPushVertexUniformData(command_buffer, 0, std.mem.asBytes(&projection_ubo));

            SDL3GPUPushFragmentUniformData(command_buffer, 0, std.mem.asBytes(&default_glyph_ubo));
            SDL3GPUBindVertexStorageBuffers(render_pass, .{default_glyph_buffer});
            SDL3GPUBindFragmentSampler(render_pass, default_glyph_texture, default_glyph_sampler);

            SDL3GPUDraw(render_pass, GlyphInstance.VertexCount, default_glyph_count);

            SDL3GPUPushFragmentUniformData(command_buffer, 0, std.mem.asBytes(&mono_glyph_ubo));
            SDL3GPUBindVertexStorageBuffers(render_pass, .{mono_glyph_buffer});
            SDL3GPUBindFragmentSampler(render_pass, mono_glyph_texture, mono_glyph_sampler);

            SDL3GPUDraw(render_pass, GlyphInstance.VertexCount, mono_glyph_count);
        }

        SDL3EndGPURenderPass(render_pass);

        try SDL3SubmitGPUCommandBuffer(command_buffer);
    }
}
