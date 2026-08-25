pub const std = @import("std");

pub const FontDescription = struct {
    path: []const u8,
};

pub const FontConfiguration = struct {
    pub const Bounds = struct {
        left: f32,
        bottom: f32,
        right: f32,
        top: f32,
    };

    pub const Glyph = struct {
        unicode: u32,
        advance: f32,
        planeBounds: ?Bounds = null,
        atlasBounds: ?Bounds = null,
    };

    pub const Metrics = struct {
        emSize: f32,
        lineHeight: f32,
        ascender: f32,
        descender: f32,
        underlineY: f32,
        underlineThickness: f32,
    };

    pub const AtlasConfig = struct {
        type: []const u8,
        distanceRange: f32,
        distanceRangeMiddle: f32,
        size: f32,
        width: u32,
        height: u32,
        yOrigin: []const u8,
    };

    atlas: AtlasConfig,
    metrics: Metrics,
    glyphs: []const Glyph,
};

pub const Font = struct {
    data: []const u8,
    config: FontConfiguration,
};
