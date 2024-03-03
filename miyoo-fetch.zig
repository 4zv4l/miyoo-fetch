const std = @import("std");
const log = std.log;
const fmt = std.fmt;
const http = std.http;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// get ID from user
// free memory before returning
fn getRomID(allocator: Allocator) !usize {
    var stdin = std.io.getStdIn().reader();
    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();
    try stdin.streamUntilDelimiter(array.writer(), '\n', 1024);
    return try fmt.parseUnsigned(usize, array.items, 10);
}

// get the ROM name from the website using the ID
// caller is the owner of the rom name (need to free)
fn getRomName(allocator: Allocator, client: *http.Client, headers: *http.Headers, id: usize) ![]const u8 {
    // format url
    const url = try fmt.allocPrint(allocator, "https://edgeemu.net/details-{d}.htm", .{id});
    log.info("Requesting rom's info...", .{});
    defer allocator.free(url);
    const uri = try std.Uri.parse(url);

    // do ther request
    var req = try client.request(.GET, uri, headers.*, .{});
    defer req.deinit();
    try req.start();
    try req.wait();

    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();

    log.info("Looking for ROM's name", .{});
    while (req.reader().streamUntilDelimiter(array.writer(), '\n', 1024)) {
        if (std.mem.startsWith(u8, array.items, "Name:  ")) {
            const start = 7; // skip "Name:  "
            const _end = std.mem.indexOf(u8, array.items, "<");
            if (_end) |end| {
                // if Rom's name is empty
                if (start == end) return error.RomNotFound;
                return try allocator.dupe(u8, array.items[start..end]);
            }
            return error.NameError;
        }
        try array.resize(0);
    } else |_| {}

    return error.RomNotFound;
}

// download rom by chunk of 4kb into `filename`
fn downloadFile(allocator: Allocator, client: *http.Client, headers: *http.Headers, filename: []const u8, id: usize) !void {
    // open destination file
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    log.info("Opened destination file", .{});

    // format url
    const url = try fmt.allocPrint(allocator, "https://edgeemu.net/down.php?id={d}", .{id});
    log.info("Requesting download...", .{});
    defer allocator.free(url);
    const uri = try std.Uri.parse(url);

    var req = try client.request(.GET, uri, headers.*, .{});
    defer req.deinit();
    try req.start();
    try req.wait();

    log.info("Downloading...", .{});
    var buff: [4096]u8 = undefined;
    while (true) {
        const read = try req.readAll(&buff);
        _ = try file.writeAll(buff[0..read]);
        if (read < buff.len) break;
    }
    log.info("Downloaded !", .{});
}

pub fn main() !void {
    // setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // setup http client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    // setup headers (None)
    var headers = http.Headers{ .allocator = allocator };
    defer headers.deinit();

    print("Welcome ! Please enter the rom ID from edgeemu.net:\n", .{});

    const id = try getRomID(allocator);
    const name = try getRomName(allocator, &client, &headers, id);
    defer allocator.free(name);
    const filename = try fmt.allocPrint(allocator, "{s}.7z", .{name});
    defer allocator.free(filename);

    log.info("Rom's id: {d} !", .{id});
    log.info("Rom's name: {s} !", .{name});

    try downloadFile(allocator, &client, &headers, filename, id);
}
