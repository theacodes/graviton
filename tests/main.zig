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

var stream_data: [40]i32 = undefined;
var stream_index: usize = 0;

fn stream_read(_: ?*anyopaque) callconv(.C) i32 {
    var data = stream_data[stream_index];
    stream_index += 1;
    return data;
}

test "GravitonDatagram read from stream (success)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_OK);
    try testing.expect(dg.start == 0x55);
    try testing.expect(dg.src == 1);
    try testing.expect(dg.dst == 2);
    try testing.expect(dg.protocol == 3);
    try testing.expect(dg.crc8 == 0x04);
    try testing.expect(dg.stop == 0x2A);
}

test "GravitonDatagram read from stream (no start byte)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_NO_START_BYTE);
}

test "GravitonDatagram read from stream (no end byte)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_NO_END_BYTE);
}

test "GravitonDatagram read from stream (bad crc8)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x0A, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_BAD_CRC8);
}

test "GravitonDatagram read from stream (success, but with retries)" {
    stream_index = 0;
    stream_data = [_]i32{
        -1,   0x55, 0x01, -1,   0x02, 0x03, -1,   0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, -1,   -1,   0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, -1,   0x00, 0x00, 0x00, 0x00, 0x00, -1,   0x00, 0x00,
        0x00, -1,   0x00, 0x00, 0x00, 0x00, 0x2A,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_OK);
    try testing.expect(dg.start == 0x55);
    try testing.expect(dg.src == 1);
    try testing.expect(dg.dst == 2);
    try testing.expect(dg.protocol == 3);
    try testing.expect(dg.crc8 == 0x04);
    try testing.expect(dg.stop == 0x2A);
}

test "GravitonDatagram read from stream (abort)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, -2,   0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_ABORTED);
}

test "GravitonDatagram read from stream (unknown error)" {
    stream_index = 0;
    stream_data = [_]i32{
        0x55, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, -3,   0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x2A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };

    var dg: GravitonDatagram = undefined;
    var result = c.GravitonDatagram_read(&dg, &stream_read, undefined);

    try testing.expect(result == c.GRAVITON_READ_UNKNOWN);
}

test "Phason GetFeederInfo req/resp" {
    var req = c.struct_PhasonRequest{
        .command = c.PHASON_GET_FEEDER_INFO_REQ,
        .data = undefined,
    };

    var dg = c.PhasonRequest_to_datagram(0x42, &req);
    try testing.expect(c.GravitonDatagram_check_crc8(&dg));
    try testing.expect(dg.src == 0x00);
    try testing.expect(dg.dst == 0x42);
    try testing.expect(dg.protocol == c.PHASON_PROTOCOL_ID);
    try testing.expect(dg.payload[0] == c.PHASON_GET_FEEDER_INFO_REQ);

    var resp = c.struct_PhasonGetFeederInfoResponse{
        .command = c.PHASON_GET_FEEDER_INFO_RESP,
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
    try testing.expect(std.meta.eql(dg.payload, [_]u8{ c.PHASON_GET_FEEDER_INFO_RESP, c.PHASON_OK, 1, 22, 12, 16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 0, 0, 0, 0, 0, 0, 0 }));

    var decoded = c.PhasonGetFeederInfoResponse_from_datagram(&dg).*;
    try testing.expect(std.meta.eql(resp, decoded));
}
