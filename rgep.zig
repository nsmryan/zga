const std = @import("std");
const ga = @import("ga.zig");

const expect = std.testing.expect;
const assert = std.debug.assert;

pub fn rotation(pop_src: *Pop, pop_dst: *Pop, pr: f32, random: *Random) void {
    var ind_index: usize = 0;

    while (ind_index < pop_src.inds.len) : (ind_index += 1) {
        if (random.float(f32) < pr) {
            var rotation_point = random.intRangeAtMost(usize, 0, pop_src.inds.len - 1);
            rotate(u8, &pop_src.inds[ind_index].ind, &pop_dst.inds[ind_index], rotation_point);
        }
    }
}

pub fn rotate(comptime T: type, src: []const T, dst: []T, rotation_index: usize) void {
    assert(rotation_index < src.len);
    assert(dst.len == src.len);

    var loc_index: usize = 0;
    while (loc_index < src.len) : (loc_index += 1) {
        const index: usize = @mod(loc_index + rotation_index, src.len);

        dst[loc_index] = src[index];
    }
}

test "rotation" {
    var src = [_]u8{ 0, 0, 1, 1, 1 };
    var dst = [_]u8{ 0, 0, 0, 0, 0 };
    rotate(u8, src[0..], dst[0..], 2);

    expect(dst[0] == 1);
    expect(dst[1] == 1);
    expect(dst[2] == 1);
    expect(dst[3] == 0);
    expect(dst[4] == 0);
}

pub fn two_point_crossover(pop: *Pop, rand: *std.rand.Random, pc: f32) void {
    const ind_len = pop.inds[0].locs.len;

    var pair_index: usize = 0;
    while (pair_index < (pop.inds.len / 2)) : (pair_index += 1) {
        if (rand.float(f32) < pc) {
            const first_index = pair_index * 2;
            const second_index = pair_index * 2 + 1;

            const cross_point0 = rand.intRangeAtMost(usize, 0, ind_len - 1);
            const cross_point1 = rand.intRangeAtMost(usize, cross_point0, ind_len - 1);
            ga.cross(cross_point0, pop.inds[first_index].locs, pop.inds[second_index].locs);
            ga.cross(cross_point1, pop.inds[first_index].locs, pop.inds[second_index].locs);
        }
    }
}

test "two cross points" {
    var first = [_]u8{ 1, 1, 1, 1, 1 };
    var second = [_]u8{ 0, 0, 0, 0, 0 };
    ga.cross(1, first[0..], second[0..]);
    ga.cross(3, first[0..], second[0..]);

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
