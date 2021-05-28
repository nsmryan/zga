const std = @import("std");
const ga = @import("ga.zig");

const expect = std.testing.expect;
const assert = std.debug.assert;

pub fn one_point_crossover(pop: *ga.Pop, rand: *std.rand.Random, pc: f32) void {
    const ind_len = pop.inds[0].locs.len;

    var pair_index: usize = 0;
    while (pair_index < (pop.inds.len / 2)) : (pair_index += 1) {
        if (rand.float(f32) < pc) {
            const first_index = pair_index * 2;
            const second_index = pair_index * 2 + 1;

            const cross_point = rand.intRangeAtMost(usize, 0, ind_len - 1);
            cross(cross_point, pop.inds[first_index].locs, pop.inds[second_index].locs);
        }
    }
}

pub fn cross(cross_point: usize, first: []u8, second: []u8) void {
    assert(first.len == second.len);
    assert(cross_point < first.len);
    assert(cross_point < second.len);

    var loc_index: usize = 0;
    while (loc_index < cross_point) : (loc_index += 1) {
        std.mem.swap(u8, &first[loc_index], &second[loc_index]);
    }
}

test "cross" {
    const allocator = std.heap.page_allocator;

    const byte_count = 10;
    var bytes = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes, 0);

    var bytes2 = try allocator.alloc(u8, byte_count);
    std.mem.set(u8, bytes2, 1);

    expect(bytes[0] == 0);
    expect(bytes[byte_count - 1] == 0);
    expect(bytes2[0] == 1);
    expect(bytes2[byte_count - 1] == 1);

    cross(byte_count / 2, bytes, bytes2);

    expect(bytes[0] == 1);
    expect(bytes[byte_count - 1] == 0);
    expect(bytes2[0] == 0);
    expect(bytes2[byte_count - 1] == 1);
}

pub fn two_point_crossover(pop: *ga.Pop, rand: *std.rand.Random, pc: f32) void {
    const ind_len = pop.inds[0].locs.len;

    var pair_index: usize = 0;
    while (pair_index < (pop.inds.len / 2)) : (pair_index += 1) {
        if (rand.float(f32) < pc) {
            const first_index = pair_index * 2;
            const second_index = pair_index * 2 + 1;

            const cross_point0 = rand.intRangeAtMost(usize, 0, ind_len - 1);
            const cross_point1 = rand.intRangeAtMost(usize, cross_point0, ind_len - 1);
            cross(cross_point0, pop.inds[first_index].locs, pop.inds[second_index].locs);
            cross(cross_point1, pop.inds[first_index].locs, pop.inds[second_index].locs);
        }
    }
}

test "two cross points" {
    var first = [_]u8{ 1, 1, 1, 1, 1 };
    var second = [_]u8{ 0, 0, 0, 0, 0 };
    cross(1, first[0..], second[0..]);
    cross(3, first[0..], second[0..]);

    expect(second[0] == 0);
    expect(second[1] == 1);
    expect(second[2] == 1);
    expect(second[3] == 0);
    expect(second[4] == 0);

    expect(first[0] == 1);
    expect(first[1] == 0);
    expect(first[2] == 0);
    expect(first[3] == 1);
    expect(first[4] == 1);
}
