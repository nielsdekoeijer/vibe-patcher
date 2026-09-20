const std = @import("std");
const ipc = @import("ipc");

pub fn main(init: std.process.Init) !void {
    const client_ip = std.Io.net.Ip4Address.loopback(0);
    const server_ip = std.Io.net.Ip4Address.loopback(9999);

    var client = try ipc.Client.init(init.io, .{ .ip4 = client_ip });
    defer client.deinit();

    _ = try client.send(init.gpa, .{ .ip4 = server_ip }, .{ .Quit = .{} });
}
