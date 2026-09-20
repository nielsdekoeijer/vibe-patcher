const std = @import("std");
const ipc = @import("ipc");

const usage =
    \\Usage: patcher-ctl <command> [arguments]
    \\
    \\Commands:
    \\  quit
    \\  screenshot <path.bmp>
    \\  mouse-press <x> <y> <left|middle|right> <down|up>
    \\  mouse-move <x> <y> <xrel> <yrel>
    \\  scroll <x> <y>
    \\  key-press <key> <down|up>
    \\  help
    \\
;

fn parseDirection(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "down")) return true;
    if (std.mem.eql(u8, value, "up")) return false;
    return error.InvalidDirection;
}

fn parseMouseButton(value: []const u8) !ipc.MouseButton {
    if (std.mem.eql(u8, value, "left")) return .Left;
    if (std.mem.eql(u8, value, "middle")) return .Middle;
    if (std.mem.eql(u8, value, "right")) return .Right;
    return error.InvalidMouseButton;
}

fn parseCommand(args: []const [:0]const u8) !ipc.Command {
    if (args.len < 2) return error.MissingCommand;

    const command = args[1];
    if (std.mem.eql(u8, command, "quit")) {
        if (args.len != 2) return error.InvalidArguments;
        return .{ .Quit = .{} };
    }

    if (std.mem.eql(u8, command, "screenshot")) {
        if (args.len != 3) return error.InvalidArguments;
        return .{ .Screenshot = .{ .path = args[2] } };
    }

    if (std.mem.eql(u8, command, "mouse-press")) {
        if (args.len != 6) return error.InvalidArguments;
        return .{ .MousePress = .{
            .x = try std.fmt.parseFloat(f32, args[2]),
            .y = try std.fmt.parseFloat(f32, args[3]),
            .button = try parseMouseButton(args[4]),
            .down = try parseDirection(args[5]),
        } };
    }

    if (std.mem.eql(u8, command, "mouse-move")) {
        if (args.len != 6) return error.InvalidArguments;
        return .{ .MouseMove = .{
            .x = try std.fmt.parseFloat(f32, args[2]),
            .y = try std.fmt.parseFloat(f32, args[3]),
            .xrel = try std.fmt.parseFloat(f32, args[4]),
            .yrel = try std.fmt.parseFloat(f32, args[5]),
        } };
    }

    if (std.mem.eql(u8, command, "scroll")) {
        if (args.len != 4) return error.InvalidArguments;
        return .{ .Scroll = .{
            .x = try std.fmt.parseFloat(f32, args[2]),
            .y = try std.fmt.parseFloat(f32, args[3]),
        } };
    }

    if (std.mem.eql(u8, command, "key-press")) {
        if (args.len != 4) return error.InvalidArguments;
        return .{ .KeyPress = .{
            .key = try std.fmt.parseInt(u32, args[2], 0),
            .down = try parseDirection(args[3]),
        } };
    }

    return error.UnknownCommand;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (args.len == 2 and (std.mem.eql(u8, args[1], "help") or std.mem.eql(u8, args[1], "--help"))) {
        try stdout.writeAll(usage);
        try stdout.flush();
        return;
    }

    const command = parseCommand(args) catch |err| {
        var stderr_buffer: [4096]u8 = undefined;
        var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
        const stderr = &stderr_writer.interface;

        try stderr.print("error: {s}\n\n{s}", .{ @errorName(err), usage });
        try stderr.flush();
        std.process.exit(2);
    };

    const client_ip = std.Io.net.Ip4Address.loopback(0);
    const server_ip = std.Io.net.Ip4Address.loopback(9999);

    var client = try ipc.Client.init(init.io, .{ .ip4 = client_ip });
    defer client.deinit();

    const response = try client.send(init.arena.allocator(), .{ .ip4 = server_ip }, command);
    try std.zon.stringify.serialize(response, .{}, stdout);
    try stdout.writeByte('\n');
    try stdout.flush();
}
