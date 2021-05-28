const std = @import("std");
const ga = @import("ga.zig");
const tourn = @import("tournament.zig");
const rotation = @import("rotation.zig");
const crossover = @import("crossover.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;

const StackError = error{
    Overflow,
    Underflow,
};

pub fn Stack(comptime T: type) type {
    return struct {
        slots: []T,
        sp: usize,

        pub fn create(slots: []T) Stack(T) {
            return Stack(T){ .slots = slots, .sp = 0 };
        }

        pub fn push(stack: *Stack(T), item: T) StackError!void {
            if (stack.sp < stack.slots.len) {
                stack.slots[stack.sp] = item;
                stack.sp += 1;
            } else {
                return StackError.Overflow;
            }
        }

        pub fn pop(stack: *Stack(T)) StackError!T {
            if (stack.sp > 0) {
                stack.sp -= 1;
                return stack.slots[stack.sp];
            } else {
                return StackError.Underflow;
            }
        }

        pub fn clear(stack: *Stack(T)) void {
            stack.sp = 0;
        }
    };
}

pub fn Symbol(comptime T: type) type {
    return struct {
        const Self = @This();

        name: u8,
        num_in: usize,
        num_out: usize,
        op: fn (*Stack(T)) StackError!void,

        pub fn new(name: u8, num_in: usize, num_out: usize, op: fn (*Stack(T)) StackError!void) Self {
            return Self{ .name = name, .num_in = num_in, .num_out = num_out, .op = op };
        }
    };
}

fn pusher(comptime T: type, name: u8, item: T) Symbol(T) {
    const fun = struct {
        fn inner(stack: *Stack(f32)) StackError!void {
            try stack.push(item);
        }
    };

    return Symbol(T).new(name, 0, 1, fun.inner);
}

test "pusher" {
    var slots: [3]f32 = undefined;
    var stack = Stack(f32).create(slots[0..]);

    try sym_push_zero.op(&stack);
    try sym_push_one.op(&stack);
    try sym_push_two.op(&stack);

    expect(stack.sp == 3);
    expect(stack.slots[0] == 0);
    expect(stack.slots[1] == 1);
    expect(stack.slots[2] == 2);
}

const sym_push_zero: Symbol(f32) = pusher(f32, '0', 0);
const sym_push_one: Symbol(f32) = pusher(f32, '1', 1);
const sym_push_two: Symbol(f32) = pusher(f32, '2', 2);

fn sym_f32(comptime name: u8, comptime op: fn (f32, f32) f32) Symbol(f32) {
    const fun = struct {
        fn inner(stack: *Stack(f32)) StackError!void {
            const first = try stack.pop();
            const second = try stack.pop();
            try stack.push(op(first, second));
        }
    };
    return Symbol(f32).new(name, 2, 1, fun.inner);
}

fn add(first: f32, second: f32) f32 {
    return first + second;
}
const sym_add: Symbol(f32) = sym_f32('+', add);

fn sub(first: f32, second: f32) f32 {
    return second - first;
}
const sym_sub: Symbol(f32) = sym_f32('-', sub);

fn mul(first: f32, second: f32) f32 {
    return first * second;
}
const sym_mul: Symbol(f32) = sym_f32('*', mul);

fn div(first: f32, second: f32) f32 {
    if (first != 0.0) {
        return second / first;
    } else {
        return 0.0;
    }
}
const sym_div: Symbol(f32) = sym_f32('/', div);

test "stack f32 ops" {
    var slots: [2]f32 = undefined;
    var stack = Stack(f32).create(slots[0..]);

    try sym_push_one.op(&stack);
    try sym_push_two.op(&stack);

    try sym_add.op(&stack);

    expect(stack.sp == 1);
    expect(stack.slots[0] == 3);

    try sym_push_two.op(&stack);
    try sym_mul.op(&stack);

    expect(stack.sp == 1);
    expect(stack.slots[0] == 6);

    try sym_push_two.op(&stack);
    try sym_div.op(&stack);

    expect(stack.sp == 1);
    expect(stack.slots[0] == 3);

    try sym_push_two.op(&stack);
    try sym_sub.op(&stack);

    expect(stack.sp == 1);
    expect(stack.slots[0] == 1);
}

pub fn Decoder(comptime T: type) type {
    return struct {
        const Self = @This();

        terminals: []Symbol(T),
        nonterminals: []Symbol(T),

        pub fn create(terminals: []Symbol(T), nonterminals: []Symbol(T)) Self {
            return Self{ .terminals = terminals, .nonterminals = nonterminals };
        }

        pub fn decode(decoder: *Self, gene: u8) Symbol(T) {
            const is_terminal = gene & 1 == 0;
            const index = gene >> 1;

            var symbols: []Symbol(T) = undefined;
            if (is_terminal) {
                symbols = decoder.terminals;
            } else {
                symbols = decoder.nonterminals;
            }

            return symbols[index % symbols.len];
        }
    };
}

pub fn express_f32(ind: []u8, decoder: *Decoder(f32), stack: *Stack(f32)) f32 {
    stack.clear();

    var loc_index: usize = 0;
    while (loc_index < ind.len) : (loc_index += 1) {
        const sym = decoder.decode(ind[loc_index]);
        // run operation, ignoring errors
        sym.op(stack) catch {};
    }

    return stack.pop() catch 0;
}

test "express f32" {
    var terminals = [_]Symbol(f32){ sym_push_zero, sym_push_one, sym_push_two };
    var non_terminals = [_]Symbol(f32){ sym_add, sym_sub, sym_div, sym_mul };
    var decoder = Decoder(f32).create(terminals[0..], non_terminals[0..]);

    const stdout = std.io.getStdOut();
    try stdout.writer().print("\n", .{});
    try stdout.writer().print("decode 0 {c}\n", .{decoder.decode(0x00).name});
    try stdout.writer().print("decode 2 {c}\n", .{decoder.decode(0x02).name});
    try stdout.writer().print("decode 1 {c}\n", .{decoder.decode(0x01).name});
    try stdout.writer().print("decode 3 {c}\n", .{decoder.decode(0x03).name});

    expectEqual(sym_push_zero.name, decoder.decode(0).name);
    expectEqual(sym_add.name, decoder.decode(1).name);

    var slots: [32]f32 = undefined;
    std.mem.set(f32, slots[0..], 0.0);
    var stack: Stack(f32) = Stack(f32).create(slots[0..]);

    var ind = [_]u8{ 2, 2, 1 };

    const result: f32 = express_f32(ind[0..], &decoder, &stack);
    const expected: f32 = 2.0;
    expectEqual(expected, result);
}

pub fn max_f32_evaluation(pop: *ga.Pop, decoder: *Decoder(f32), fitnesses: []f32) void {
    var slots: [32]f32 = undefined;
    std.mem.set(f32, slots[0..], 0.0);
    var stack: Stack(f32) = Stack(f32).create(slots[0..]);

    var ind_index: usize = 0;
    while (ind_index < pop.inds.len) : (ind_index += 1) {
        fitnesses[ind_index] = express_f32(pop.inds[ind_index].locs, decoder, &stack);
    }
}

pub fn most_elite(pop: *ga.Pop, fitnesses: []f32, elite: *ga.Ind) void {
    var fittest: usize = 0;
    var fit_index: usize = 0;
    while (fit_index < fitnesses.len) : (fit_index += 1) {
        if (fitnesses[fit_index] > fitnesses[fittest]) {
            fittest = fit_index;
        }
    }

    std.mem.copy(u8, elite.locs, pop.inds[fittest].locs);
}

pub fn ensure_elite(pop: *ga.Pop, elite: *ga.Ind) void {
    std.mem.copy(u8, pop.inds[0].locs, elite.locs);
}

pub fn main() !void {
    const POP_SIZE = 30;
    const IND_SIZE = 160;
    const GENS = 10000;

    const PM: f32 = 0.001;
    const PR: f32 = 0.001;
    const PC: f32 = 0.6;
    const PC2: f32 = 0.6;
    const PT: f32 = 0.9;

    const allocator = std.heap.page_allocator;

    var rng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = &rng.random;

    var pop = try ga.Pop.new(POP_SIZE, IND_SIZE, allocator);
    defer pop.free(allocator);

    pop.randomize(rand);

    var pop_other = try ga.Pop.new(POP_SIZE, IND_SIZE, allocator);
    defer pop_other.free(allocator);

    var elite = try ga.Ind.new(IND_SIZE, allocator);
    defer elite.free(allocator);

    var pop_src = &pop;
    var pop_dest = &pop_other;

    const stdout = std.io.getStdOut();

    var fitnesses: []f32 = try allocator.alloc(f32, POP_SIZE);
    defer allocator.free(fitnesses);

    var terminals = [_]Symbol(f32){ sym_push_zero, sym_push_one, sym_push_two };
    var non_terminals = [_]Symbol(f32){ sym_add, sym_sub, sym_div, sym_mul };
    var decoder = Decoder(f32).create(terminals[0..], non_terminals[0..]);

    var gens: usize = 0;
    while (gens < GENS) : (gens += 1) {
        try stdout.writer().print("gen {}\n", .{gens});

        max_f32_evaluation(pop_src, &decoder, fitnesses);

        most_elite(pop_src, fitnesses, &elite);

        tourn.two_tournament_selection(pop_src, pop_dest, fitnesses, PT, rand);
        std.mem.swap(*ga.Pop, &pop_src, &pop_dest);

        ga.point_mutation(pop_src, rand, PM);

        rotation.rotation(pop_src, rand, PR);

        crossover.one_point_crossover(pop_src, rand, PC);

        crossover.two_point_crossover(pop_src, rand, PC2);

        ensure_elite(pop_src, &elite);
    }

    max_f32_evaluation(pop_src, &decoder, fitnesses);

    var fit_index: usize = 0;
    while (fit_index < fitnesses.len) : (fit_index += 1) {
        try stdout.writer().print("fitness {}\n", .{@floatToInt(i32, fitnesses[fit_index])});

        var loc_index: usize = 0;
        while (loc_index < pop_src.inds[fit_index].locs.len) : (loc_index += 1) {
            const sym = decoder.decode(pop_src.inds[fit_index].locs[loc_index]);
            try stdout.writer().print("{c}", .{sym.name});
        }
        try stdout.writer().print("\n", .{});
    }
}
