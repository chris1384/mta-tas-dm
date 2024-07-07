-- // CREDITS: Nipy (contact: @nipy on Discord)
-- // From MTA - DM Mappers Community (Join: https://discord.gg/WeUrNhG)
-- // https://discord.com/channels/407150722191327242/407950505973907456/1201563765372624956

function dot_product(v1, v2)
    local product = 0
    for i = 1, #v1 do
        product = product + v1[i] * v2[i]
    end
    return product
end

function magnitude(v)
    local sum_of_squares = 0
    for i = 1, #v do
        sum_of_squares = sum_of_squares + v[i]^2
    end
    return math.sqrt(sum_of_squares)
end

function matrix_multiply(m, v)
    local result = {0, 0, 0}
    for i = 1, 3 do
        for j = 1, 3 do
            result[i] = result[i] + m[i][j] * v[j]
        end
    end
    return result
end

function direction_vector(rotation, direction)
    local x = math.rad(rotation[1])
    local y = math.rad(rotation[2])
    local z = math.rad(rotation[3])

    local Rx = {{1, 0, 0}, {0, math.cos(x), -math.sin(x)}, {0, math.sin(x), math.cos(x)}}
    local Ry = {{math.cos(y), 0, math.sin(y)}, {0, 1, 0}, {-math.sin(y), 0, math.cos(y)}}
    local Rz = {{math.cos(z), -math.sin(z), 0}, {math.sin(z), math.cos(z), 0}, {0, 0, 1}}

	-- // edited by @chris1384
    local v = {1, 0, 0} -- default "x"
    if direction == "y" then
        v = {0, 1, 0}
    elseif direction == "z" then
        v = {0, 0, 1}
    end

    v = matrix_multiply(Rx, v)
    v = matrix_multiply(Ry, v)
    v = matrix_multiply(Rz, v)

    return v
end

function is_within_tolerance(v1, v2, tolerance)
    local dot_product = dot_product(v1, v2)
    local product_of_magnitudes = magnitude(v1) * magnitude(v2)
    local cos_angle = dot_product / product_of_magnitudes

    return cos_angle >= math.cos(math.rad(tolerance))
end
