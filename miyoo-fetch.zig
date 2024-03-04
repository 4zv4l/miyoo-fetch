const std = @import("std");
const log = std.log;
const fmt = std.fmt;
const fs = std.fs;
const http = std.http;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// keep log.info even in ReleaseFast
pub const std_options = .{ .log_level = .info };

const DownloadOptions = struct {
    // optional filename to use for the output file
    filename: ?[]const u8 = null,
    // optional callback function for the progress of the download
    callback: ?fn (current: usize, total: ?usize, filename: []const u8) void = null,
};

// download a file from `uri` using `client`
fn download(client: *http.Client, uri: std.Uri, buff: []u8, options: DownloadOptions) !usize {
    // setup http request
    var headers_buffer: [16 * 1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &headers_buffer });
    defer req.deinit();

    // send http request and wait for the response
    try req.send(.{});
    try req.wait();

    // get file info (Content-Length / Content-Disposition: filename="{s}")
    const file_size = req.response.content_length;
    const file_name = if (options.filename) |name| name else blk: {
        if (req.response.content_disposition) |content| {
            var content_fields = std.mem.split(u8, content, "; ");
            while (content_fields.next()) |field| {
                if (std.mem.containsAtLeast(u8, field, 1, "filename=")) {
                    var it = std.mem.split(u8, field, "\"");
                    if (it.next()) |_| if (it.next()) |name| break :blk name;
                }
            }
        }
        break :blk "fetch.out"; // use a temporary file instead ?
    };

    // create or overwrite the file
    var file = try fs.cwd().createFile(file_name, .{});
    defer file.close();

    // download the file
    var currently_read: usize = 0;
    while (true) {
        if (options.callback) |call| call(currently_read, file_size, file_name);
        const read = try req.readAll(buff);
        _ = try file.writer().writeAll(buff[0..read]);
        currently_read += read;
        if (read < buff.len) break;
    }
    if (options.callback) |call| call(currently_read, file_size, file_name);
    return currently_read;
}

// callback used when downloading the file
fn progress(current: usize, total: ?usize, filename: []const u8) void {
    if (total) |tot| {
        if (current == tot) {
            print("\rDone downloading {d}kb [{s}]\n", .{ current / 1024, filename });
        } else {
            print("\rDownloading {d}/{d}kb [{s}]", .{ current / 1024, tot / 1024, filename });
        }
    } else {
        print("\rDownloading {d}kb [{s}]", .{ current / 1024, filename });
    }
}

// read a number from `reader`
fn readUsize(reader: anytype) !usize {
    var array: std.BoundedArray(u8, 128) = .{};
    try reader.streamUntilDelimiter(array.writer(), '\n', 128);
    return try fmt.parseUnsigned(usize, array.buffer[0..array.len], 10);
}

pub fn main() !void {
    // setup the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // setup http client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    print("Welcome !\nPlease enter the rom ID from edgeemu.net: ", .{});

    // get rom ID from user and setup the target uri for download
    const id = try readUsize(std.io.getStdIn().reader());
    const url = try fmt.allocPrint(allocator, "https://edgeemu.net/down.php?id={d}", .{id});
    defer allocator.free(url);
    const uri = try std.Uri.parse(url);

    // allocate 8mb for the download buffer and download the file
    const buff = try allocator.alloc(u8, 8 * 1024 * 1024);
    defer allocator.free(buff);
    _ = try download(&client, uri, buff, .{ .callback = progress });
    log.info("Thanks for using me :)", .{});
}
