-- Utility: emulate bitwise ops using arithmetic
local function band(a, b)
    local res = 0
    for i = 0, 31 do
        local x = a % 2
        local y = b % 2
        if x + y > 1.5 then res = res + 2^i end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return res
end

local function bor(a, b)
    local res = 0
    for i = 0, 31 do
        if a % 2 + b % 2 > 0 then res = res + 2^i end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return res
end

local function bxor(a, b)
    local res = 0
    for i = 0, 31 do
        local abit = a % 2
        local bbit = b % 2
        if abit ~= bbit then res = res + 2^i end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
    end
    return res
end

local function rshift(x, n)
    return math.floor(x / 2^n) % 2^32
end

local function lshift(x, n)
    return (x * 2^n) % 2^32
end

local function rotr(x, n)
    return bor(rshift(x, n), lshift(x, 32 - n))
end

-- Padding helpers
local function to_bytes(s)
    local bytes = {}
    for i = 1, #s do
        bytes[#bytes+1] = s:byte(i)
    end
    return bytes
end

local function from_bytes(b)
    local s = ""
    for i = 1, #b do
        s = s .. string.char(b[i])
    end
    return s
end

local function pad_msg(msg)
    local ml = #msg * 8
    msg = msg .. "\128"
    while (#msg % 64) ~= 56 do
        msg = msg .. "\0"
    end
    for i = 7, 0, -1 do
        msg = msg .. string.char(math.floor(ml / (2^(i*8))) % 256)
    end
    return msg
end

local function to_u32(b, i)
    return b[i]*2^24 + b[i+1]*2^16 + b[i+2]*2^8 + b[i+3]
end

-- Constants
local H = {
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
}

local K = {
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0xFC19DC6,  0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x6CA6351,  0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2
}

-- Main SHA256 logic
local function sha256(msg)
    local m = to_bytes(pad_msg(msg))
    local h = {table.unpack(H)}

    for i = 1, #m, 64 do
        local w = {}
        for j = 0, 15 do
            w[j] = to_u32(m, i + j*4)
        end
        for j = 16, 63 do
            local s0 = bxor(rotr(w[j-15], 7), rotr(w[j-15], 18), rshift(w[j-15], 3))
            local s1 = bxor(rotr(w[j-2], 17), rotr(w[j-2], 19), rshift(w[j-2], 10))
            w[j] = (w[j-16] + s0 + w[j-7] + s1) % 2^32
        end

        local a,b,c,d,e,f,g,hv = table.unpack(h)

        for j = 0, 63 do
            local S1 = bxor(rotr(e, 6), rotr(e, 11), rotr(e, 25))
            local ch = bxor(band(e, f), band((e) % 2^32, g))
            local temp1 = (hv + S1 + ch + K[j+1] + w[j]) % 2^32
            local S0 = bxor(rotr(a, 2), rotr(a, 13), rotr(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = (S0 + maj) % 2^32

            hv = g
            g = f
            f = e
            e = (d + temp1) % 2^32
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 2^32
        end

        h[1] = (h[1] + a) % 2^32
        h[2] = (h[2] + b) % 2^32
        h[3] = (h[3] + c) % 2^32
        h[4] = (h[4] + d) % 2^32
        h[5] = (h[5] + e) % 2^32
        h[6] = (h[6] + f) % 2^32
        h[7] = (h[7] + g) % 2^32
        h[8] = (h[8] + hv) % 2^32
    end

    local hash = ""
    for i = 1, 8 do
        hash = hash .. string.format("%08x", h[i])
    end
    return hash
end

-- Example
-- print(sha256("abc"))
return sha256
