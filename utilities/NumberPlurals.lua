local PluralCase = {
    Zero = "zero",
    One = "one",
    Two = "two",
    Few = "few",
    Many = "many",
    Other = "other",
}

local function getCardinalPluralCase_en(numericValue)
    local i = math.tointeger(numericValue)
    if i == nil or i ~= 1 then
        return PluralCase.Other
    end
    return PluralCase.One
end

function GetCardinalPluralCase(languageCode, numericValue)
    -- Currently only supports English
    return getCardinalPluralCase_en(numericValue)
end

local function getOrdinalPluralCase_en(numericValue)
    local i = math.abs(numericValue)

    if i % 10 == 1 and i % 100 ~= 11 then
        return PluralCase.One
    elseif i % 10 == 2 and i % 100 ~= 12 then
        return PluralCase.Two
    elseif i % 10 == 3 and i % 100 ~= 13 then
        return PluralCase.Few
    else
        return PluralCase.Other
    end
end

function GetOrdinalPluralCase(languageCode, numericValue)
    -- Currently only supports English
    return getOrdinalPluralCase_en(numericValue)
end