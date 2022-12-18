// Copyright 2022 Winterbloom LLC & Alethea Katherine Flowers
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE.md file or at
// https://opensource.org/licenses/MIT.

const c = @cImport({
    @cInclude("graviton.h");
    @cInclude("phason.h");
});

const GravitonDatagram = c.struct_GravitonDatagram;

const std = @import("std");
const print = std.debug.print;
const testing = std.testing;

test "graviton_crc8" {
    // Validated against https://crccalc.com/
    var data = [_]u8{ 0x00, 0x01, 0x02, 0x03 };
    var crc = c.graviton_crc8(&data, data.len);
    try testing.expect(crc == 0x48);
}

test "GravitonDatagram init" {
    var dg: GravitonDatagram = undefined;
    c.GravitonDatagram_init(&dg, 1, 2, 3);
    try testing.expect(dg.start == 0x55);
    try testing.expect(dg.src == 1);
    try testing.expect(dg.dst == 2);
    try testing.expect(dg.protocol == 3);
    try testing.expect(dg.stop == 0x2A);
}

test "GravitonDatagram crc8 set and check" {
    var dg: GravitonDatagram = undefined;
    c.GravitonDatagram_init(&dg, 1, 2, 3);
    // Datagram bytes:
    //  0x55 0x01 0x02 0x03 0x00 0x00 0x00 0x00
    //  0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
    //  0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
    //  0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x2A
    // Validated against https://crccalc.com/
    c.GravitonDatagram_set_crc8(&dg);
    try testing.expect(dg.crc8 == 0x04);
    try testing.expect(c.GravitonDatagram_check_crc8(&dg));
}

var stream_read_data: [40]i32 = undefined;
var stream_read_index: usize = 0;
var stream_write_data: [40]u8 = undefined;
var stream_write_index: usize = 0;

fn stream_read(_: [*c]c.GravitonIO) callconv(.C) i32 {
    if (stream_read_index >= stream_read_data.len) {
        return -2;
    }

    var data = stream_read_data[stream_read_index];
    stream_read_index += 1;
    return data;
}

fn stream_write(_: [*c]c.GravitonIO, data: [*c]u8, len: usize) callconv(.C) i32 {
    if (stream_write_index + len >= stream_write_data.len) {
        return -2;
    }

    var i: usize = 0;
    while (i < len) {
        stream_write_data[stream_write_index] = data[i];
        stream_write_index += 1;
        i += 1;
    }

    return @intCast(i32, len);
}

fn stream_reset() void {
    std.mem.set(i32, &stream_read_data, 0);
    std.mem.set(u8, &stream_write_data, 0);
    stream_read_index = 0;
    stream_write_index = 0;
}

var stream_io = c.GravitonIO{
    .read = &stream_read,
    .write = &stream_write,
    .context = undefined,
};

test "GravitonDatagram read from stream (success)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expect(result == c.GRAVITON_READ_OK);
    try testing.expect(dg.start == 0x55);
    try testing.expect(dg.src == 1);
    try testing.expect(dg.dst == 2);
    try testing.expect(dg.protocol == 3);
    try testing.expect(dg.crc8 == 0x04);
    try testing.expect(dg.stop == 0x2A);
}

test "GravitonDatagram read from stream (no start byte)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expect(result == c.GRAVITON_READ_NO_START_BYTE);
}

test "GravitonDatagram read from stream (no end byte)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expect(result == c.GRAVITON_READ_NO_END_BYTE);
}

test "GravitonDatagram read from stream (bad crc8)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x0A, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expect(result == c.GRAVITON_READ_BAD_CRC8);
}

test "GravitonDatagram read from stream (success, but with retries)" {
    stream_reset();
    stream_read_data = [_]i32{
        -1,   0x55, 0x01, -1,   0x02, 0x03, -1,   0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, -1,   -1,   0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, -1,   0x00, 0x00, 0x00, 0x00, 0x00, -1,   0x00, 0x00,
        0x00, -1,   0x00, 0x00, 0x00, 0x00, 0x2A,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expect(result == c.GRAVITON_READ_OK);
    try testing.expect(dg.start == 0x55);
    try testing.expect(dg.src == 1);
    try testing.expect(dg.dst == 2);
    try testing.expect(dg.protocol == 3);
    try testing.expect(dg.crc8 == 0x04);
    try testing.expect(dg.stop == 0x2A);
}

test "GravitonDatagram read from stream (abort)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, -2,   0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expectEqual(result, c.GRAVITON_READ_ABORTED);
}

test "GravitonDatagram read from stream (unknown error)" {
    stream_reset();
    stream_read_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, -3,   0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read_from_stream(&dg, &stream_io);

    try testing.expectEqual(result, c.GRAVITON_READ_UNKNOWN);
}

test "Phason to/from datagram" {
    var req = c.struct_PhasonRequest{
        .command = c.PHASON_FEEDER_INFO_REQ,
        .data = undefined,
    };

    var dg = c.PhasonRequest_to_datagram(0x42, &req);
    try testing.expect(c.GravitonDatagram_check_crc8(&dg));
    try testing.expect(dg.src == 0x00);
    try testing.expect(dg.dst == 0x42);
    try testing.expect(dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(dg.payload[0] == c.PHASON_FEEDER_INFO_REQ);

    var resp = c.struct_PhasonFeederInfoResponse{
        .command = c.PHASON_FEEDER_INFO_RESP,
        .status = c.PHASON_OK,
        .protocol_version = 1,
        .firmware_year = 22,
        .firmware_month = 12,
        .firmware_day = 16,
        .uid = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 },
        .padding = undefined,
    };

    dg = c.PhasonResponse_to_datagram(0x42, &resp);
    try testing.expect(c.GravitonDatagram_check_crc8(&dg));
    try testing.expect(dg.src == 0x42);
    try testing.expect(dg.dst == 0x00);
    try testing.expect(dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(std.meta.eql(dg.payload, [_]u8{ c.PHASON_FEEDER_INFO_RESP, c.PHASON_OK, 1, 22, 12, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 0, 0, 0, 0, 0, 0, 0 }));

    var decoded = c.PhasonFeederInfoResponse_from_datagram(&dg);
    try testing.expect(std.meta.eql(resp, decoded));
}

fn unpack_i32(bytes: []u8) i32 {
    return @ptrCast(*align(1) i32, bytes).*;
}

test "Phason StartFeedRequest to datagram" {
    var req = c.struct_PhasonStartFeedRequest{
        .command = c.PHASON_START_FEED_REQ,
        .sequence = 1,
        .micrometers = -42,
        .padding = undefined,
    };

    var dg = c.PhasonRequest_to_datagram(0x42, &req);
    try testing.expect(c.GravitonDatagram_check_crc8(&dg));
    try testing.expect(dg.src == 0x00);
    try testing.expect(dg.dst == 0x42);
    try testing.expect(dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(dg.payload[0] == c.PHASON_START_FEED_REQ);
    try testing.expect(dg.payload[1] == 1);
    try testing.expectEqual(unpack_i32(dg.payload[2..6]), -42);
}

test "Phason send request" {
    stream_reset();

    var req = c.struct_PhasonStartFeedRequest{
        .command = c.PHASON_START_FEED_REQ,
        .sequence = 42,
        .micrometers = 52,
        .padding = undefined,
    };

    var resp = c.struct_PhasonStartFeedResponse{
        .command = c.PHASON_START_FEED_RESP,
        .status = c.PHASON_OK,
        .sequence = 42,
        .padding = undefined,
    };

    var resp_dg = c.PhasonResponse_to_datagram(0x42, &resp);
    for (c.GravitonDatagram_as_bytes(&resp_dg)[0..32]) |b, i| {
        stream_read_data[i] = b;
    }

    var actual_resp_dg: GravitonDatagram = undefined;
    var result = c.phason_send_request(&stream_io, 0x42, @ptrCast(*c.struct_PhasonRequest, &req), &actual_resp_dg);

    try testing.expectEqual(result, c.GRAVITON_READ_OK);

    // Check the request data written
    var req_dg = c.GravitonDatagram_from_bytes(&stream_write_data);
    try testing.expect(c.GravitonDatagram_check_crc8(&req_dg));
    try testing.expect(req_dg.src == 0x00);
    try testing.expect(req_dg.dst == 0x42);
    try testing.expect(req_dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(req_dg.payload[0] == c.PHASON_START_FEED_REQ);
    try testing.expect(req_dg.payload[1] == 42);
    try testing.expectEqual(unpack_i32(req_dg.payload[2..6]), 52);

    // Check the decoded response data
    var actual_resp = c.PhasonStartFeedResponse_from_datagram(&actual_resp_dg);
    try testing.expectEqual(actual_resp.command, c.PHASON_START_FEED_RESP);
    try testing.expectEqual(actual_resp.status, c.PHASON_OK);
    try testing.expectEqual(actual_resp.sequence, 42);
}

test "Phason send response" {
    stream_reset();
    var resp = c.struct_PhasonStartFeedResponse{
        .command = c.PHASON_START_FEED_RESP,
        .status = c.PHASON_OK,
        .sequence = 42,
        .padding = undefined,
    };

    var result = c.phason_send_response(&stream_io, 0x42, @ptrCast(*c.struct_PhasonResponse, &resp));

    try testing.expect(result >= 0);

    var resp_dg = c.GravitonDatagram_from_bytes(&stream_write_data);
    try testing.expect(c.GravitonDatagram_check_crc8(&resp_dg));
    try testing.expect(resp_dg.src == 0x42);
    try testing.expect(resp_dg.dst == 0x00);
    try testing.expect(resp_dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(resp_dg.payload[0] == c.PHASON_START_FEED_RESP);
    try testing.expect(resp_dg.payload[1] == c.PHASON_OK);
    try testing.expect(resp_dg.payload[2] == 42);
}
