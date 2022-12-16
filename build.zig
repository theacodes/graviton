// Copyright 2022 Winterbloom LLC & Alethea Katherine Flowers
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE.md file or at
// https://opensource.org/licenses/MIT.

const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const rel_opts = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const cflags = [_][]const u8{
        "-std=gnu11",
        "-W",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-Wshadow",
        "-Wundef",
        "-Wint-conversion",
        "-Wformat=2",
    };

    const main = b.addTest("tests/main.zig");
    main.setBuildMode(rel_opts);
    main.setTarget(target);
    main.linkSystemLibrary("c");
    main.addIncludePath("src/");
    main.addCSourceFile("tests/dummy.c", &cflags);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&main.step);
    b.default_step.dependOn(test_step);
}
