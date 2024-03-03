// ram usage is around 1.5mb
// 500kb    for the http request/response
// 1mb      for the file download buffering
const std = @import("std");
const log = std.log;
const fmt = std.fmt;
const http = std.http;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// keep log.info even in ReleaseFast
pub const std_options = .{ .log_level = .info };

// get ID from user
fn getFileID() !usize {
    var stdin = std.io.getStdIn().reader();
    var array: std.BoundedArray(u8, 128) = .{};
    try stdin.streamUntilDelimiter(array.writer(), '\n', 128);
    return try fmt.parseUnsigned(usize, array.buffer[0..array.len], 10);
}

// download file from url as `filename`
fn downloadFile(allocator: Allocator, client: *http.Client, uri: std.Uri, filename: ?[]const u8) !void {
    // setup http request
    const headers_buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(headers_buffer);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = headers_buffer });
    defer req.deinit();

    // send http request and wait for the response
    try req.send(.{});
    try req.wait();

    // get file info
    const file_size = req.response.content_length.?;
    const file_name = blk: {
        const content = req.response.content_disposition.?;
        var it = std.mem.split(u8, content, "\"");
        _ = it.next(); // skip first one
        break :blk it.next().?;
    };

    // log file info
    log.info("filename: {s}", .{file_name});
    log.info("Downloading {d}kb", .{file_size / 1024});

    // create target file (overwrite if already exists !)
    const target_file = if (filename != null) filename.? else file_name;
    var file = try std.fs.cwd().createFile(target_file, .{});
    defer file.close();

    // download file by chunk if 1mb
    var buff: [1024 * 1024]u8 = undefined;
    var currently_read: usize = 0;
    while (true) {
        print("\rinfo: Downloaded {d}/{d}kb", .{ currently_read / 1024, file_size / 1024 });
        const read = try req.readAll(&buff);
        _ = try file.writeAll(buff[0..read]);
        currently_read += read;
        if (read < buff.len) break;
    }
    print("\rinfo: Downloaded {d}/{d}kb\n", .{ currently_read / 1024, file_size / 1024 });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // setup http client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    print("Welcome !\nPlease enter the rom ID from edgeemu.net: ", .{});

    // get file ID from user and setup the target uri for download
    const id = try getFileID();
    const url = try fmt.allocPrint(allocator, "https://edgeemu.net/down.php?id={d}", .{id});
    defer allocator.free(url);
    const uri = try std.Uri.parse(url);

    try downloadFile(allocator, &client, uri, null);
    log.info("Thanks for using me :)", .{});
}
