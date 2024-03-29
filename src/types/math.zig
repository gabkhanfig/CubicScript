const std = @import("std");
const expect = std.testing.expect;
const root = @import("../root.zig");
const Int = root.Int;

pub const MAX_INT = std.math.maxInt(Int);
pub const MIN_INT = std.math.minInt(Int);

// https://ziglang.org/documentation/master/#Wrapping-Operations

/// Returns a tuple of the resulting addition, as well as a bool for if integer overflow (or underflow) occurred.
/// If overflow occurrs, the result is wrapped around.
pub fn addOverflow(a: Int, b: Int) struct { Int, bool } {
    var didOverflow = false;
    if (a >= 0) {
        if (b > (MAX_INT - a)) {
            didOverflow = true;
        }
    } else {
        if (b < (MIN_INT -% a)) {
            didOverflow = true;
        }
    }

    const temp = a +% b;
    return .{ temp, didOverflow };
}

/// Returns a tuple of the resulting subtraction, as well as a bool for if integer overflow (or underflow) occurred.
/// If overflow occurrs, the result is wrapped around.
pub fn subOverflow(a: Int, b: Int) struct { Int, bool } {
    // https://stackoverflow.com/questions/1633561/how-to-detect-overflow-when-subtracting-two-signed-32-bit-numbers-in-c
    var didOverflow = false;
    if (b > 0 and (a < (MIN_INT + b))) {
        didOverflow = true;
    }
    if (b < 0 and (a > (MAX_INT + b))) {
        didOverflow = true;
    }

    const temp = a -% b;
    return .{ temp, didOverflow };
}

/// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow (or underflow) occurred.
/// If overflow occurrs, the result is wrapped around.
pub fn mulOverflow(a: Int, b: Int) struct { Int, bool } {
    // https://stackoverflow.com/questions/54318815/integer-overflow-w-multiplication-in-c
    var didOverflow = false;

    if (a == MIN_INT and b == -1) {
        return .{ MIN_INT, true };
    }

    if (b > 0) {
        if (a > @divTrunc(MAX_INT, b) or a < @divTrunc(MIN_INT, b)) {
            didOverflow = true;
        }
    } else if (b < 0) {
        if (b == -1) {
            if (a == MIN_INT) {
                didOverflow = true;
            }
        } else {
            if (a < @divTrunc(MAX_INT, b) or a > @divTrunc(MIN_INT, b)) {
                didOverflow = true;
            }
        }
    }
    const temp = a *% b;
    return .{ temp, didOverflow };
}

/// Returns a tuple of the resulting multiplication, as well as a bool for if integer overflow (or underflow) occurred.
/// If overflow occurrs, the result is wrapped around.
/// If `base == 0` and `exp < 0`, this is a hard error as 0 raised to a negative exponent is undefined.
/// For `b < 0`, the returning value will be 0 without an overflow, since it is a mathetically correct exponentiation floored.
pub fn powOverflow(base: Int, exp: Int) error{ZeroPowNegative}!struct { Int, bool } {
    if (base == 0 and exp < 0) {
        return error.ZeroPowNegative;
    }
    if (base == 1 or exp == 0) {
        return .{ 1, false };
    }
    if (base == -1 or base == 0) {
        return .{ base, false };
    }

    // base >= 2 or base <= -2 from this point
    if (exp < 0) {
        return .{ 0, false }; // basically like float exponent floored
    }

    var didOverflow = false;
    var baseLoop = base;
    var expLoop = exp;
    var accumulate: Int = 1;
    while (expLoop > 1) {
        if (expLoop & 1 == 1) {
            const temp = mulOverflow(accumulate, baseLoop);
            if (temp[1] == true) {
                didOverflow = true;
            }
            accumulate = temp[0];
        }

        expLoop >>= 1;
        {
            const temp = mulOverflow(baseLoop, baseLoop);
            if (temp[1] == true) {
                didOverflow = true;
            }
            baseLoop = temp[0];
        }
    }

    if (expLoop == 1) {
        const temp = mulOverflow(accumulate, baseLoop);
        if (temp[1] == true) {
            didOverflow = true;
        }
        accumulate = temp[0];
    }

    return .{ accumulate, didOverflow };
}

test "add overflow" {
    {
        const result = addOverflow(1, 1);
        try expect(result.@"0" == 2);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(-1, 1);
        try expect(result.@"0" == 0);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(1, -1);
        try expect(result.@"0" == 0);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(100, 2);
        try expect(result.@"0" == 102);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(-100, -2);
        try expect(result.@"0" == -102);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(MIN_INT, 1);
        try expect(result.@"0" == MIN_INT + 1);
        try expect(result.@"1" == false);
    }
    {
        const result = addOverflow(MAX_INT, 1); // actually overflow
        try expect(result.@"0" == MIN_INT);
        try expect(result.@"1" == true);
    }
    {
        const result = addOverflow(MIN_INT, -1); // actually overflow
        try expect(result.@"0" == MAX_INT);
        try expect(result.@"1" == true);
    }
}

test "sub overflow" {
    {
        const result = subOverflow(1, 1);
        try expect(result.@"0" == 0);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(-1, 1);
        try expect(result.@"0" == -2);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(1, -1);
        try expect(result.@"0" == 2);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(100, 2);
        try expect(result.@"0" == 98);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(-100, -2);
        try expect(result.@"0" == -98);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(MAX_INT, 1);
        try expect(result.@"0" == MAX_INT - 1);
        try expect(result.@"1" == false);
    }
    {
        const result = subOverflow(MIN_INT, 1); // actually overflow
        try expect(result.@"0" == MAX_INT);
        try expect(result.@"1" == true);
    }
    {
        const result = subOverflow(MAX_INT, -1); // actually overflow
        try expect(result.@"0" == MIN_INT);
        try expect(result.@"1" == true);
    }
}

test "mul overflow" {
    {
        const result = mulOverflow(1, 1);
        try expect(result.@"0" == 1);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(-1, 1);
        try expect(result.@"0" == -1);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(1, -1);
        try expect(result.@"0" == -1);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(100, 2);
        try expect(result.@"0" == 200);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(-100, -2);
        try expect(result.@"0" == 200);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(MAX_INT, 1);
        try expect(result.@"0" == MAX_INT);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(MIN_INT, 1);
        try expect(result.@"0" == MIN_INT);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(MAX_INT, -1);
        try expect(result.@"0" == MIN_INT + 1);
        try expect(result.@"1" == false);
    }
    {
        const result = mulOverflow(MIN_INT, -1); // this will overflow because the value cannot be represented
        try expect(result.@"1" == true);
    }
    {
        const result = mulOverflow(MIN_INT, 2); // actually overflow
        try expect(result.@"1" == true);
    }
    {
        const result = mulOverflow(MAX_INT, 2); // actually overflow
        try expect(result.@"1" == true);
    }
    {
        const result = mulOverflow(MIN_INT, -2); // actually overflow
        try expect(result.@"1" == true);
    }
    {
        const result = mulOverflow(MAX_INT, -2); // actually overflow
        try expect(result.@"1" == true);
    }
}

test "pow overflow" {
    {
        const result = try powOverflow(1, 1);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(2, 3);
        try expect(result[0] == 8);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(-2, 3);
        try expect(result[0] == -8);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(1, 0);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(2, 0);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(2, -1);
        try expect(result[0] == 0);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(2, -3);
        try expect(result[0] == 0);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(2, 0);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(1, 3);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(1, -1);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(1, -2);
        try expect(result[0] == 1);
        try expect(result[1] == false);
    }
    {
        const result = try powOverflow(MAX_INT, 2);
        try expect(result[0] == @mulWithOverflow(@as(Int, MAX_INT), @as(Int, MAX_INT))[0]);
        try expect(result[1] == true);
    }
    {
        const result = try powOverflow(-2, 65);
        try expect(result[1] == true);
    }
    {
        if (powOverflow(0, -1)) |_| {
            try expect(false);
        } else |_| {}
        if (powOverflow(0, -2)) |_| {
            try expect(false);
        } else |_| {}
    }
}
