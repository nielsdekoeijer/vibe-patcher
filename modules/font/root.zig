pub const std = @import("std");

pub const FontDescription = struct {
    /// Path to the source font file used to generate the runtime atlas.
    path: []const u8,

    /// How to map to pixels from em
    pixels_per_em: usize,
};

/// Used for serializing and deserializing the font atlas zon file
pub const FontConfiguration = struct {
    pub const Bounds = struct {
        /// Minimum horizontal coordinate of the rectangle.
        left: f32,

        /// Minimum vertical coordinate of the rectangle.
        bottom: f32,

        /// Maximum horizontal coordinate of the rectangle.
        right: f32,

        /// Maximum vertical coordinate of the rectangle.
        top: f32,
    };

    pub const Glyph = struct {
        /// Unicode code point
        unicode: u32,

        /// Horizontal movement after the glyph in em
        advance: f32,

        /// Visible glyph rectangle relative to the pen and baseline in em
        ///
        /// NOTE: null for glyphs with no visible shape, such as a space.
        planeBounds: ?Bounds = null,

        /// Rectangle containing the glyph in the atlas image denoted in atlas pixels
        ///
        /// NOTE: null for glyphs with no image in the atlas.
        atlasBounds: ?Bounds = null,
    };

    pub const Metrics = struct {
        /// Number of normalized font units per em; normally 1 in this output.
        emSize: f32,

        /// Recommended baseline-to-baseline distance, measured in em.
        lineHeight: f32,

        /// Recommended distance from the baseline to the font's upper extent, in em.
        ascender: f32,

        /// Recommended distance from the baseline to the lower extent, in em;
        /// normally negative because font-space Y points upward.
        descender: f32,

        /// Vertical position of an underline relative to the baseline, in em.
        underlineY: f32,

        /// Recommended underline thickness, measured in em.
        underlineThickness: f32,
    };

    pub const AtlasConfig = struct {
        /// Distance-field encoding stored in the atlas, for example "sdf" or "msdf".
        type: []const u8,

        /// Full signed-distance interval encoded by the atlas samples.
        /// Its exact numeric representation depends on the atlas output format.
        distanceRange: f32,

        /// Center of the encoded signed-distance interval.
        /// Its exact numeric representation depends on the atlas output format.
        distanceRangeMiddle: f32,

        /// Atlas generation scale: the number of atlas pixels per em.
        size: f32,

        /// Width of the complete atlas image, in atlas pixels.
        width: u32,

        /// Height of the complete atlas image, in atlas pixels.
        height: u32,

        /// Vertical coordinate convention used by glyph atlasBounds, usually "bottom".
        yOrigin: []const u8,
    };

    /// Image layout and signed-distance encoding information for the atlas.
    atlas: AtlasConfig,

    /// Font-wide layout measurements, expressed relative to one em.
    metrics: Metrics,

    /// Metadata mapping Unicode code points to layout and atlas rectangles.
    glyphs: []const Glyph,
};

pub const FontAtlasGlypth = struct {
    pub const Quad = struct {
        /// Coords in the sampler: [x_left, y_top, w, h]
        uv: [4]f32,

        /// Coordes on the screen; to be displaced by cursor: [x_left, y_top, w, h]
        shape: [4]f32,
    };

    quad: ?Quad,

    /// How much to move the cursor to the right after this glyph
    x_advance: f32,
};

pub fn FontAtlas(comptime configuration: FontConfiguration) type {
    return struct {
        pub const pixels_per_em = configuration.atlas.size;
        pub const aem_range = [_]f32{
            (configuration.atlas.distanceRangeMiddle - configuration.atlas.distanceRange / 2) / configuration.atlas.size,
            (configuration.atlas.distanceRangeMiddle + configuration.atlas.distanceRange / 2) / configuration.atlas.size,
        };

        pub const CharacterGlyphs: [256]FontAtlasGlypth = blk: {
            @setEvalBranchQuota(1e9);

            var atlas: [256]FontAtlasGlypth = @splat(.{ .x_advance = 0, .quad = null });

            for (configuration.glyphs) |glyph| {
                if (glyph.unicode >= atlas.len) {
                    continue;
                }

                atlas[glyph.unicode] = inner: {
                    if (glyph.planeBounds == null or glyph.atlasBounds == null) {
                        break :inner FontAtlasGlypth{
                            .x_advance = glyph.advance * pixels_per_em,
                            .quad = null,
                        };
                    }

                    break :inner FontAtlasGlypth{
                        .x_advance = glyph.advance * pixels_per_em,
                        .quad = .{
                            .uv = .{
                                glyph.atlasBounds.?.left / configuration.atlas.width,
                                glyph.atlasBounds.?.top / configuration.atlas.height,
                                glyph.atlasBounds.?.right / configuration.atlas.width,
                                glyph.atlasBounds.?.bottom / configuration.atlas.height,
                            },
                            .shape = .{
                                glyph.planeBounds.?.left * pixels_per_em,
                                glyph.planeBounds.?.top * pixels_per_em,
                                (glyph.planeBounds.?.right - glyph.planeBounds.?.left) * pixels_per_em,
                                (glyph.planeBounds.?.top - glyph.planeBounds.?.bottom) * pixels_per_em,
                            },
                        },
                    };
                };
            }

            break :blk atlas;
        };
    };
}

pub const Font = struct {
    /// Raw atlas image bytes in the channel layout selected during generation.
    data: []const u8,

    /// Generated atlas, font-metric, and per-glyph metadata describing data.
    config: FontConfiguration,
};
