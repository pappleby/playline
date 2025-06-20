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


function LineParser:ParseString(input, localeCode, addImplicitCharacterAttribute)
    local squish = true
    local sort = true
    local addImplicitCharacterAttribute = addImplicitCharacterAttribute ~= false
    assert(type(input) == "string", "input must be a string")
    -- TODO think about unicode normalization
    local tokens = self:lexMarkup(input)
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