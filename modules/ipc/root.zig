const std = @import("std");

pub const CommandTag = enum(u16) {
    Quit,
    Screenshot,
    MousePress,
    MouseMove,
    KeyPress,
};

pub const MouseButton = enum(u8) {
    Left,
    Middle,
    Right,
};

pub const Command = union(CommandTag) {
    Quit: struct {},
    Screenshot: struct {},
    MousePress: struct {
        x: f32,
        y: f32,
        button: MouseButton,
        down: bool,
    },
    MouseMove: struct {
        x: f32,
        y: f32,
        xrel: f32,
        yrel: f32,
    },
    KeyPress: struct {
        key: u32,
        down: bool,
    },
};

pub const Request = struct {
    command: Command,
    from: std.Io.net.IpAddress,
};

pub const ResponseTag = enum(u16) {
    Ok,
    Screenshot,
};

pub const Response = union(ResponseTag) {
    Ok: struct {},
    Screenshot: struct {
        path: []const u8,
    },
};

pub const Server = struct {
    io: std.Io,
    socket: std.Io.net.Socket,

    pub fn init(io: std.Io, ip: std.Io.net.IpAddress) !Server {
        return .{
            .io = io,
            .socket = try ip.bind(io, .{ .mode = .dgram, .protocol = .udp }),
        };
    }

    pub fn deinit(self: *Server) void {
        self.socket.close(self.io);

        self.* = undefined;
    }

    pub fn recv(self: *Server, allocator: std.mem.Allocator) !Request {
        var buffer: [4096:0]u8 = undefined;

        // See if there is a message for us
        const message = try self.socket.receive(self.io, &buffer);

        buffer[message.data.len] = 0;
        const slice = buffer[0..message.data.len :0];

        return .{
            .command = try std.zon.parse.fromSlice(Command, allocator, slice, null, .{}),
            .from = message.from,
        };
    }

    pub fn respond(self: *Server, request: Request, response: Response) !void {
        var buffer: [4096:0]u8 = undefined;

        var writer = std.Io.Writer.fixed(&buffer);

        try std.zon.stringify.serialize(response, .{}, &writer);

        try self.socket.send(
            self.io,
            &request.from,
            writer.buffered(),
        );
    }

    pub fn free(allocator: std.mem.Allocator, request: Request) void {
        std.zon.parse.free(allocator, request.command);
    }
};

pub const Client = struct {
    io: std.Io,
    socket: std.Io.net.Socket,

    pub fn init(io: std.Io, ip: std.Io.net.IpAddress) !Client {
        return .{
            .io = io,
            .socket = try ip.bind(io, .{ .mode = .dgram, .protocol = .udp }),
        };
    }

    pub fn deinit(self: *Client) void {
        self.socket.close(self.io);

        self.* = undefined;
    }

    pub fn send(self: *Client, allocator: std.mem.Allocator, server: std.Io.net.IpAddress, command: Command) !Response {
        {
            var buffer: [4096:0]u8 = undefined;

            var writer = std.Io.Writer.fixed(&buffer);

            try std.zon.stringify.serialize(command, .{}, &writer);

            try self.socket.send(
                self.io,
                &server,
                writer.buffered(),
            );
        }

        {
            var buffer: [4096:0]u8 = undefined;

            const message = try self.socket.receive(self.io, &buffer);

            buffer[message.data.len] = 0;
            const slice = buffer[0..message.data.len :0];

            return try std.zon.parse.fromSliceAlloc(Response, allocator, slice, null, .{});
        }
    }
};
