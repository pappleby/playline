import "CoreLibs/object"

local standardLibrary = 
{
    functions = {
        string = tostring,
        number = tonumber,
        bool = function(value)
            return value and true
        end,
        ['Number.Add'] = function(a, b)
            return a + b
        end,
        ['Number.Minus'] = function(a, b)
            return a - b
        end,
        ['Number.Multiply'] = function(a, b)
            return a * b
        end,
        ['Number.Divide'] = function(a, b)
            return a / b
        end,
        ['Number.Modulo'] = function(a, b)
            return a % b
        end,
        ['Number.GreaterThan'] = function(a, b)
            return a > b
        end,
        ['Number.LessThan'] = function(a, b)
            return a < b
        end,
        ['Number.GreaterThanOrEqualTo'] = function(a, b)
            return a >= b
        end,
        ['Number.LessThanOrEqualTo'] = function(a, b)
            return a <= b
        end,
        ['Number.EqualTo'] = function(a, b)
            return a == b
        end,
        ['Number.NotEqualTo'] = function(a, b)
            return a ~= b
        end,
        ['String.Add'] = function(a, b)
            return a .. b
        end,
        ['String.EqualTo'] = function(a, b)
            return a == b
        end,
        ['String.NotEqualTo'] = function(a, b)
            return a ~= b
        end,
        ['Bool.Or'] = function(a,b)
            return a or b
        end,
        ['Bool.Xor'] = function(a,b)
            return (a or b) and not (a and b)
        end,
        ['Bool.Not'] = function(a)
            return not a
        end,
        ['Bool.And'] = function(a,b)
            return a and b
        end,
        ['Bool.EqualTo'] = function(a, b)
            return a == b
        end,
        ['Bool.NotEqualTo'] = function(a, b)
            return a ~= b
        end,
        ['Enum.EqualTo'] = function(a, b)
            return a == b
        end,
        ['Enum.NotEqualTo'] = function(a, b)
            return a ~= b
        end,
        random = math.random,
        random_range = function(min, max)
            return math.random(math.modf(min), math.modf(max))
        end,
        random_range_float = function(minInclusive, maxInclusive)
            return math.random(math.modf(maxInclusive) - math.modf(minInclusive)) + minInclusive
        end,
        dice = function (sides)
            return math.random(1, sides)
        end,
        min = math.min,
        max = math.max,
        round = function(value)
            return math.modf(math.floor(value + 0.5))
        end,
        round_places = function(value, places)
            local factor = 10 ^ places
            return math.floor(value * factor + 0.5) / factor
        end,
        floor = math.floor,
        ceil = math.ceil,
        inc = function(value)
            if math.type(value) == "integer" then
                return value + 1
            else
                return math.ceil(value)
            end
        end,
        dec = function(value)
            if math.type(value) == "integer" then
                return value - 1
            else
                return math.floor(value)
            end
        end,
        decimal = function(n)
            return select(2,math.modf(n))
        end,
        int = function(n)
            if(n>=0) then
                return math.floor(n)
            else 
                return math.ceil(n)
            end
        end,
},
    commands = {
        wait = function(secondsString)
            local seconds = tonumber(secondsString)
            assert(type(seconds) == "number", "Wait command expects a number as argument.")
            return coroutine.create(function()
                local startTime = playdate.getCurrentTimeMilliseconds()
                local ms = seconds * 1000
                while (playdate.getCurrentTimeMilliseconds() - startTime) < (ms) do
                    coroutine.yield()
                end
                print("Waited for " .. seconds .. " seconds.")
            end)
        end,
    }
}

---@class Library
class('Library').extends()
function Library:init(useStandardLibrary)
    self.functions = {}
    self.commands = {}
    if useStandardLibrary then
        self:importLibrary(standardLibrary)
    end
end

function Library:getFunction(name)
    local result = self.functions[name]
    assert(result, "Function '" .. name .. "' not found in library.")
    return result
end

function Library:getCommand(name)
    local result = self.functions[name]
    assert(result, "Function '" .. name .. "' not found in library.")
    return result
end

function Library:importLibrary(other)
    for name, func in pairs(other.functions) do
        self.functions[name] = func
    end
    for name, command in pairs(other.commands) do
        self.commands[name] = command
    end
end

function Library:registerFunction(name, func)
    self.functions[name] = func
end

function Library:functionExists(name)
    return self.functions[name] ~= nil
end

function Library:deregisterFunction(name)
    self.functions[name] = nil
end

function Library:registerCommand(name, command)
    self.commands[name] = command
end
function Library:commandExists(name)
    return self.commands[name] ~= nil
end
function Library:deregisterCommand(name)
    self.commands[name] = nil
end
function GenerateUniqueVisitedVariableForNode(nodeName)
    return '$Yarn.Internal.Visiting.' .. nodeName
end

