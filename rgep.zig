const std = @import("std");
const ga = @import("ga.zig");
const tourn = @import("tournament.zig");
const rotation = @import("rotation.zig");
const crossover = @import("crossover.zig");

const expect = std.testing.expect;
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

fn pusher(comptime T: type, item: T) Symbol(T) {
    const fun = struct {
        fn inner(stack: *Stack(f32)) StackError!void {
            try stack.push(item);
        }
    };

    return Symbol(T).new('1', 0, 1, fun.inner);
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

const sym_push_zero: Symbol(f32) = pusher(f32, 0);
const sym_push_one: Symbol(f32) = pusher(f32, 1);
const sym_push_two: Symbol(f32) = pusher(f32, 2);

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
    if (second != 0.0) {
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
        terminals: []Symbol,
        nonterminals: []Symbol,

        pub fn create(terminals: []Symbol, nonterminals: []Symbol) Decoder {
            return Decoder{ .terminals = terminals, .nonterminals = nonterminals };
        }

        pub fn decode(decoder: *Decoder, gene: u8) Symbol {
            const is_terminal = @intToBool(gene & 1);
            const index = gene >> 1;

            var symbols = undefined;
            if (is_terminal) {
                symbols = decoder.terminal;
            } else {
                symbols = decoder.nonterminals;
            }

            return symbols[index % symbols.len];
        }
    };
}

pub fn max_f32_evaluation(pop: *ga.Pop, fitnesses: []f32) void {}

pub fn main() !void {
    const POP_SIZE = 100;
    const IND_SIZE = 128;
    const GENS = 1000;

    const PM: f32 = 0.005;
    const PR: f32 = 0.005;
    const PC: f32 = 0.7;
    const PC2: f32 = 0.7;
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

    var pop_src = &pop;
    var pop_dest = &pop_other;

    const stdout = std.io.getStdOut();

    var fitnesses: []f32 = try allocator.alloc(f32, POP_SIZE);
    defer allocator.free(fitnesses);

    var gens: usize = 0;
    while (gens < GENS) : (gens += 1) {
        try stdout.writer().print("gen {}\n", .{gens});

        max_f32_evaluation(pop_src, fitnesses);

        tourn.two_tournament_selection(pop_src, pop_dest, fitnesses, PC, rand);

        std.mem.swap(*ga.Pop, &pop_src, &pop_dest);

        ga.point_mutation(pop_src, rand, PM);

        rotation.rotation(pop_src, pop_dest, rand, PR);
        std.mem.swap(*ga.Pop, &pop_src, &pop_dest);

        crossover.one_point_crossover(pop_src, rand, PC);

        crossover.two_point_crossover(pop_src, rand, PC2);
    }

    max_f32_evaluation(pop_src, fitnesses);
}
