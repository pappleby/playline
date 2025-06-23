import "CoreLibs/object"
import "utils.lua"

---@class LineParser
class('LineParser').extends()

function LineParser:init()
   self.markerProcessors = {}
end

---@enum LexerTokenType
local LexerTokenTypes = {
    Text = {},
    OpenMarker = {},
    CloseMarker = {},
    CloseSlash = {},
    Identifier = {},
    Error = {},
    Start = {},
    End = {},
    Equals = {},
    StringValue = {},
    NumberValue = {},
    BooleanValue = {},
    InterpolatedValue = {},
}


---@enum LexerMode
local LexerMode = {
    Text = {},
    Tag = {},
    Value = {},
}

---@class LexerToken
class('LexerToken').extends()
function LexerToken:init(lexerType, startPos, endPos)
    self.Type = lexerType or LexerTokenTypes.Text
    self.Start = startPos or 0
    self.End = endPos or 0
end

function LexerToken:Range()
    return self.End + 1 - self.Start
end

function LineParser:lexMarkup(input)
    if(input == "") then
        return {LexerToken(LexerTokenTypes.Start, 0, 0), LexerToken(LexerTokenTypes.End, 0, 0)}
    end
    local tokens = {}
    local mode = LexerMode.Text
    local last = LexerToken(LexerTokenTypes.Start, 0, 0) -- should think about if this should be 0 or 1 if theses are all 1-based indices
    table.insert(tokens, last)
    local readerOutput = {nil}
    local reader = StringReader(input, readerOutput)
    local currentPosition = 1;
    while (reader:Read()) ~= nil do
        local c = readerOutput[1] -- Get the character read by the reader
        if(mode == LexerMode.Text) then
            local isPreviousCharBackslash = (last.Type == LexerTokenTypes.Text and input[last.End] == "\\")
            if(c == "[" and ~isPreviousCharBackslash) then
                last = LexerToken(LexerTokenTypes.OpenMarker, currentPosition, currentPosition)
                table.insert(tokens, last)
                mode = LexerMode.Tag
            else
                if(last.Type == LexerTokenTypes.Text) then
                    -- if the last token is also a text we want to extend it
                    last.End = currentPosition
                else
                    -- otherwise we make a new text token
                    last = LexerToken(LexerTokenTypes.Text, currentPosition, currentPosition)
                    table.insert(tokens, last)
                end
            end
        elseif(mode == LexerMode.Tag) then
            -- we are in tag mode, this means different rules for text basically
            if(c == "]") then
                last = LexerToken(LexerTokenTypes.CloseMarker, currentPosition, currentPosition)
                table.insert(tokens, last)
                mode = LexerMode.Text
            elseif(c == "/") then
                last = LexerToken(LexerTokenTypes.CloseSlash, currentPosition, currentPosition)
                table.insert(tokens, last)
            elseif(c == "=") then
                last = LexerToken(LexerTokenTypes.Equals, currentPosition, currentPosition)
                table.insert(tokens, last)
                mode = LexerMode.Value
            else
                -- if we are inside tag mode and ARENT one of the above specific tokens we MUST be an identifier
                -- so this means we want to eat characters until we are no longer a valid identifier character
                -- at which point we close off the identifier token and let lexing continue as normal
                if(StringHelper.IsLetterOrDigit(c)) then
                    local endPos = StringHelper.FindEndOfAlphanumeric(input, currentPosition)
                    reader:SkipPastIndex(endPos)
                    last = LexerToken(LexerTokenTypes.Identifier, currentPosition, endPos)
                    table.insert(tokens, last)
                    currentPosition = endPos
                elseif(~StringHelper.IsWhitespace(c)) then
                    -- if we are whitespace we likely want to just continue because it's most likely just spacing between identifiers
                    -- the only time this isn't allowed is if they split the marker name, but that is a parser issue not a lexer issue
                    -- so basically if we encounter a non-alphanumeric or non-whitespace we error
                    last = LexerToken(LexerTokenTypes.Error, currentPosition, currentPosition)
                    table.insert(tokens, last)
                    mode = LexerMode.Text
                end
                table.insert(tokens, last)
            end
        elseif(mode == LexerMode.Value) then
            -- we are in value mode now
            if (StringHelper.IsWhitespace(c)) then
                -- whitespace is allowed in value mode, so we just continue
            elseif(c == "-" or StringHelper.IsDigit(c)) then
                --- we are a number
                local endPos = StringHelper.FindEndOfNumber(input, currentPosition)
                local token = LexerToken(LexerTokenTypes.NumberValue, currentPosition, endPos)
                if(endPos == nil) then
                    token.Type = LexerTokenTypes.Error
                    token.End = currentPosition
                    endPos = currentPosition
                end
                reader:SkipPastIndex(endPos)
                currentPosition = endPos
                table.insert(tokens, token)
                last = token
                mode = LexerMode.Tag
            elseif(c == '"') then
                -- we are a string value, so we need to find the end of the string
                local endPos = StringHelper.FindEndOfQuotedString(input, currentPosition)
                local token = LexerToken(LexerTokenTypes.StringValue, currentPosition, endPos)
                if(endPos == nil) then
                    token.Type = LexerTokenTypes.Error
                    token.End = currentPosition
                    endPos = currentPosition
                end
                reader:SkipPastIndex(endPos)
                currentPosition = endPos
                table.insert(tokens, token)
                last = token
                mode = LexerMode.Tag
            elseif(c=="{") then
                local endPos = StringHelper.FindEndOfInterpolatedValue(input, currentPosition)
                local token = LexerToken(LexerTokenTypes.InterpolatedValue, currentPosition, endPos)
                if(endPos == nil) then
                    token.Type = LexerTokenTypes.Error
                    token.End = currentPosition
                    endPos = currentPosition
                end
                reader:SkipPastIndex(endPos)
                currentPosition = endPos
                table.insert(tokens, token)
                last = token
                mode = LexerMode.Tag
            else
                -- we have either true/false or generic alphanumeric text
                local endPos = StringHelper.FindEndOfAlphanumeric(input, currentPosition)
                local token = LexerToken(LexerTokenTypes.StringValue, currentPosition, endPos)
                local isBool = StringHelper.IsBoolean(string.sub(currentPosition, endPos))
                if (isBool) then token.Type = LexerTokenTypes.BooleanValue end
                table.insert(tokens, token)
                reader:SkipPastIndex(endPos)
                currentPosition = endPos
                mode = LexerMode.Tag
                last = token
            end

        else
            -- we are in an invalid mode somehow, lex as errors
            last = LexerToken(LexerTokenTypes.Error, currentPosition, currentPosition)
            table.insert(tokens, last)
        end

        currentPosition = currentPosition + 1
    end
    last = LexerToken(LexerTokenTypes.End, currentPosition, #input)
    table.insert(tokens, last)
    return tokens
end

local CleanUpUnmatchedCloses = function(openNodes, unmatchedCloseNames, errors)
    -- TODO this is not implemented yet
end

local TryNumberFromToken = function(input, token)
    local valueString = string.sub(input, token.Start, token.End)
    local value = tonumber(valueString)
    if value then
        return value
    else
        return fail, valueString
    end
end

local TryBoolFromToken = function(input, token)
    local valueString = string.sub(input, token.Start, token.End)
    if valueString == "true" then
        return true
    elseif valueString == "false" then
        return false
    end

    return fail, valueString
end

local ValueFromToken = function(input, token)
    local valueString = string.sub(input, token.Start, token.End)
    if(#valueString >= 2 and valueString[1] == "\"" and valueString[#valueString]  == "\"") then
        -- if we are inside delimiters we will also need to remove any escaped characters
        -- and trim the enclosing quotes
        valueString = string.gsub(string.sub(valueString, 2, #valueString - 1), "\\\\", "")
    end
    return valueString
end

local ValueFromInterpolatedToken = function(input, token)
    local valueString = string.sub(input, token.Start, token.End)
    -- removing the { } from the interpolated value
    valueString = string.gsub(valueString, "^{", "").gsub(valueString, "}$", "")
    return valueString
end


local comparePattern = function(tokens, startIndex, pattern)
    if(#tokens <= pattern + startIndex - 1) then
        return false
    end
    for i = 1, #pattern do
        if(tokens[startIndex + i - 1].Type ~= pattern[i]) then
            return false
        end
    end
    return true
end

-- [ / ]
local closeAllPattern = { LexerTokenTypes.OpenMarker, LexerTokenTypes.CloseSlash, LexerTokenTypes.CloseMarker }
-- [ / ID ]
local closeOpenAttributePattern = { LexerTokenTypes.OpenMarker, LexerTokenTypes.CloseSlash, LexerTokenTypes.Identifier, LexerTokenTypes.CloseMarker }
-- [ / ~( ID | ] ) 
local closeErrorPattern = { LexerTokenTypes.OpenMarker, LexerTokenTypes.CloseSlash }
-- [ ID ]
local openAttributePropertyLessPattern = { LexerTokenTypes.OpenMarker, LexerTokenTypes.Identifier, LexerTokenTypes.CloseMarker }
-- ID = VALUE
local numberPropertyPattern = { LexerTokenTypes.Identifier, LexerTokenTypes.Equals, LexerTokenTypes.NumberValue }
local booleanPropertyPattern = { LexerTokenTypes.Identifier, LexerTokenTypes.Equals, LexerTokenTypes.BooleanValue }
local stringPropertyPattern = { LexerTokenTypes.Identifier, LexerTokenTypes.Equals, LexerTokenTypes.StringValue }
local interpolatedPropertyPattern = { LexerTokenTypes.Identifier, LexerTokenTypes.Equals, LexerTokenTypes.InterpolatedValue }
-- / ]
local selfClosingAttributeEndPattern = { LexerTokenTypes.CloseSlash, LexerTokenTypes.CloseMarker }

function LineParser:buildMarkupTreeFromTokens(tokens, input)
    local tree = {name= nil, firstToken= nil, children = {}, properties = {}}
    

    local diagnostic = {}
    if tokens == nil or #tokens < 2 then
        table.insert(diagnostic, {message = "No tokens found in input.", column = 0}) -- do we ever need to return column?
        return tree, diagnostic
    end
    if #input == 0 then
        table.insert(diagnostic, {message = "There is a valid list of tokens but no original string.", column = 0})
        return tree, diagnostic
    end
    if tokens[1].Type ~= LexerTokenTypes.Start or tokens[#tokens].Type ~= LexerTokenTypes.End then
        table.insert(diagnostic, {message = "Token list doesn't start and end with the correct tokens.", column = 0})
        return tree, diagnostic
    end
    local openNodes = {}
    table.insert(openNodes, tree)
    local unmatchedCloses = {}
    local tokenIndex = 1

    while tokens[tokenIndex].Type ~= LexerTokenTypes.End do
        local tType = tokens[tokenIndex].Type
        local currentToken = tokens[tokenIndex]
        if tType == LexerTokenTypes.Text then
            -- we are adding text to the tree
            -- but first we need to make sure there aren't any closes left to clean up
            if #unmatchedCloses then
                CleanUpUnmatchedCloses(openNodes, unmatchedCloses, diagnostic)
            end
            local text = string.sub(input, currentToken.Start, currentToken.End)
            local node = {
                text = text,
                firstToken = currentToken,
            }
            table.insert(openNodes[#openNodes].children, node)
        elseif tType == LexerTokenTypes.OpenMarker then

        elseif tType == LexerTokenTypes.Identifier then
            -- ok so we are now at an identifier
            -- which is the situation we want to be in for properties of the form ID = VALUE
            -- in all situations its the same
            -- we get the id, use that to make a new property
            -- we get the value and coorce an actual value from it
            local id = string.sub(sub, currentToken.Start, currentToken.End)
            if comparePattern(tokens, tokenIndex, numberPropertyPattern) then
                local value, valueString = TryNumberFromToken(input, tokens[tokenIndex + 2])
                if value == fail then
                    table.insert(diagnostic, {message = "failed to convert the value " .. valueString .. " into a valid property (expected number)", column = currentToken.Start})
                end
                table.insert(openNodes[#openNodes].properties, {name = id, value = value})
            elseif comparePattern(tokens, tokenIndex, booleanPropertyPattern) then
                local value, valueString = TryBoolFromToken(input, tokens[tokenIndex + 2])
                if value == fail then
                    table.insert(diagnostic, {message = "failed to convert the value " .. valueString.. " into a valid property (expected boolean)", column = currentToken.Start})
                end
                table.insert(openNodes[#openNodes].properties, {name = id, value = value})
            elseif comparePattern(tokens, tokenIndex, stringPropertyPattern) then
                local value = ValueFromToken(input, tokens[tokenIndex + 2])
                table.insert(openNodes[#openNodes].properties, {name = id, value = value})
            elseif comparePattern(tokens, tokenIndex, interpolatedPropertyPattern) then
                -- don't actually know what type this is but let's just assume it's a string
                local value  = ValueFromInterpolatedToken(input, tokens[tokenIndex + 2])
                table.insert(openNodes[#openNodes].properties, {name = id, value = value})
            else 
                table.insert(diagnostic, {message = "Expected to find a property and it's value, but didn't", column = currentToken.Start})
                return tree, diagnostic -- early exit, it's already broken, and right now, don't really care about full diagnostics
            end
            tokenIndex = tokenIndex + 2 -- equivilant to stream.Consume(2)
        elseif tType == LexerTokenTypes.CloseSlash then
            -- this will only happen when we hit a self closing marker [ ID (= VALUE)? (ID = VALUE)* / ]
            -- in which case we just need to close off the current open marker as it can't have children
            if comparePattern(tokens, tokenIndex, selfClosingAttributeEndPattern) then
                -- ok last step is to add the trimwhitespace attribute in here
                local top = table.remove(openNodes)
                local found = false
                for _, property in ipairs(top.properties) do
                    if( property.name == "trimwhitespace") then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(top.properties, {name = "trimwhitespace", value = true})
                end
                tokenIndex = tokenIndex + 1 -- equivilant to stream.Consume(1)
            else
                -- we found a / but aren't part of a self closing marker
                -- at this stage this is now an error
                table.insert(diagnostic, {message = "Encountered an unexpected closing slash", column = currentToken.Start})
            end
        end
        tokenIndex = tokenIndex + 1
    end

    -- we have now run off the end of the line
    -- if we have any unmatched closes still lying around we want to close them off now
    -- because at this stage it doesn't matter about ordering

    -- ok last thing to check is is there only one element left on the stack of open nodes
    if(#openNodes > 1) then
        local line = "parsing finished with unclosed attributes still on the stack: "
        for _, node in ipairs(openNodes) do
            if node.name then
                line = line.. " [" .. node.name .. "]"
            else
                line = line .. " NULL"
            end
        end
        table.insert(diagnostic, {message = line, column = 0})
    end

    if(#unmatchedCloses > 0) then
        local line = "parsing finished with unmatched closes still remaining: "
        for _, unmatched in ipairs(unmatchedCloses) do
            line = line.. " [/" .. unmatched .. "]"
        end
        table.insert(diagnostic, {message = line, column = 0})
    end

    return tree, diagnostic
end

function LineParser:ParseString(input, localeCode, addImplicitCharacterAttribute)
    local squish = true
    local sort = true
    local addImplicitCharacterAttribute = addImplicitCharacterAttribute ~= false
    assert(type(input) == "string", "input must be a string")
    -- TODO think about unicode normalization
    local tokens = self:lexMarkup(input)
    local parseResult, diagnostics = self:buildMarkupTreeFromTokens(tokens, input)
    -- TODO IN PROGRESS: BuildMarkupTreeFromTokens (ln 1481 from LineParser.cs)
    
end
function LineParser:RegisterMarkerProcessor(attributeName, markerProcessor)
   assert(type(attributeName) == "string", "attributeName must be a string")
   assert(type(markerProcessor) == "function", "markerProcessor must be a function")
   assert(self.markerProcessors[attributeName] ~= nil, "A marker processor for ".. attributeName .. " has already been registered.")
   self.markerProcessors[marker] = processor
end

function LineParser:DeregisterMarkerProcessor(attributeName)
   self.markerProcessors[attributeName] = nil
end