import "CoreLibs/object"
import "utils.lua"

Playline = Playline or {}
local pu <const> = Playline.Utils

---@class LineParser
class('LineParser').extends()

function LineParser:init()
   self.markerProcessors = {}
   self.internalIncrementingAttribute = 1
end

---@enum LexerTokenType
local LexerTokenTypes = {
    Text = "Text",
    OpenMarker = "OpenMarker",
    CloseMarker = "CloseMarker",
    CloseSlash = "CloseSlash",
    Identifier = "Identifier",
    Error = "Error",
    Start = "Start",
    End = "End",
    Equals = "Equals",
    StringValue = "StringValue",
    NumberValue = "NumberValue",
    BooleanValue = "BooleanValue",
    InterpolatedValue = "InterpolatedValue",
}


---@enum LexerMode
local LexerMode = {
    Text = "Text",
    Tag = "Tag",
    Value = "Value",
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

class('MarkupAttribute').extends()
function MarkupAttribute:init(position, sourcePosition, length, name, properties)
    self.Position = position
    self.SourcePosition = sourcePosition
    self.Length = length
    self.Name = name
    self.Properties = table.deepcopy(properties) -- TODO consider shallow copy here
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
    local reader = pu.StringReader(input, readerOutput)
    local currentPosition = 1;
    while (reader:Read()) ~= nil do
        local c = readerOutput[1] -- Get the character read by the reader
        if(mode == LexerMode.Text) then
            local isPreviousCharBackslash = (last.Type == LexerTokenTypes.Text and input[last.End] == "\\")
            if(c == "[" and not isPreviousCharBackslash) then
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
                if(pu.StringHelper.IsLetterOrDigit(c)) then
                    local endPos = pu.StringHelper.FindEndOfAlphanumeric(input, currentPosition)
                    reader:SkipPastIndex(endPos)
                    last = LexerToken(LexerTokenTypes.Identifier, currentPosition, endPos)
                    table.insert(tokens, last)
                    currentPosition = endPos
                elseif(not pu.StringHelper.IsWhitespace(c)) then
                    -- if we are whitespace we likely want to just continue because it's most likely just spacing between identifiers
                    -- the only time this isn't allowed is if they split the marker name, but that is a parser issue not a lexer issue
                    -- so basically if we encounter a non-alphanumeric or non-whitespace we error
                    last = LexerToken(LexerTokenTypes.Error, currentPosition, currentPosition)
                    table.insert(tokens, last)
                    mode = LexerMode.Text
                end
            end
        elseif(mode == LexerMode.Value) then
            -- we are in value mode now
            if (pu.StringHelper.IsWhitespace(c)) then
                -- whitespace is allowed in value mode, so we just continue
            elseif(c == "-" or pu.StringHelper.IsDigit(c)) then
                --- we are a number
                local endPos = pu.StringHelper.FindEndOfNumber(input, currentPosition)
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
                local endPos = pu.StringHelper.FindEndOfQuotedString(input, currentPosition)
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
                local endPos = pu.StringHelper.FindEndOfInterpolatedValue(input, currentPosition)
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
                local endPos = pu.StringHelper.FindEndOfAlphanumeric(input, currentPosition)
                local token = LexerToken(LexerTokenTypes.StringValue, currentPosition, endPos)
                local isBool = pu.StringHelper.IsBoolean(string.sub(currentPosition, endPos))
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

-- this cleans up and rebalances the tree for misclosed or invalid closing patterns like the following:
-- This [a] is [b] some markup [/a][/b] invalid structure.
-- This [a] is [b] some [c] nested [/a] markup [/c] with [/b] invalid structure.
-- [z] this [a] is [b] some [c] markup [d] with [e] both [/c][/e][/d][/a][/z] misclosed tags and double unclosable tags[/b]
-- it is a variant of the adoption agency algorithm
-- if true returned, caller should clear unmatchedCloseNames
function LineParser:cleanUpUnmatchedCloses(openNodes, unmatchedCloseNames, errors)
    local orphans = {}
    -- while we still have unbalanced closes AND haven't hit the root of the tree
    while #unmatchedCloseNames > 0 and #openNodes > 1 do
        -- if the current top of the stack isn't one of the closes we will need to keep it around
        -- otherwise we just remove it from the list of closes and keep walking back up the tree
        local top = table.remove(openNodes)
        -- need to check if we already have an id
        -- if we do we don't want another one
        -- this happens when an element is split multiple times
        local hasInternalIncrementingProperty = top.properties["_internalIncrementingProperty"]
        if hasInternalIncrementingProperty == nil then
            -- adding the tracking ID property into the attribute so that we can squish them back together later
            top.properties["_internalIncrementingProperty"] = self.internalIncrementingAttribute
            self.internalIncrementingAttribute = self.internalIncrementingAttribute + 1
        end
        if top.name ~= nil then
            local removeSuccess = false
            for i, name in ipairs(unmatchedCloseNames) do
                if name == top.name then
                    table.remove(unmatchedCloseNames, i)
                    removeSuccess = true
                    break
                end
            end
            if not removeSuccess then
                table.insert(orphans, top)
            end
        end
        -- now at this point we should have no unmatched closes left
        -- if we did it meant we popped all the way to the end of the stack and are at the root and STILL didn't find that close
        -- at this point it's an error as they typoed the close marker
        if(#unmatchedCloseNames > 0) then
            for _, unmatched in ipairs(unmatchedCloseNames) do
                table.insert(errors, {message = "asked to close ".. unmatched.. " markup but there is no corresponding opening. Is [/".. unmatched.."] a typo?", column = 0})
                return true
            end
        end

        -- now on the top of the stack we have the current common ancestor of all the orphans
        -- we want to reparent them back onto the stack now as cousin clones of their original selves
        for _, template in ipairs(orphans) do
            local clone = {name = template.name, firstToken = template.firstToken, children = {}, properties = template.properties}
            table.insert(openNodes[#openNodes].children, clone)
            table.insert(openNodes, clone)
        end
    end
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
    local firstChar = valueString:sub(1, 1)
    local lastChar = valueString:sub(#valueString, #valueString)
    if(#valueString >= 2 and firstChar == "\"" and lastChar  == "\"") then
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
    if(#tokens <= #pattern + startIndex - 1) then
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
        if tType == LexerTokenTypes.Start then
            goto finishTokenLoop -- we don't do anything with the start token, just skip it
        elseif tType == LexerTokenTypes.End then
            local clearneeded = self:cleanUpUnmatchedCloses(openNodes, unmatchedCloses, diagnostic)
            if clearneeded then
                unmatchedCloses = {}
            end
            goto finishTokenLoop
        elseif tType == LexerTokenTypes.Text then
            -- we are adding text to the tree
            -- but first we need to make sure there aren't any closes left to clean up
            if #unmatchedCloses then
                local clearneeded = self:cleanUpUnmatchedCloses(openNodes, unmatchedCloses, diagnostic)
                if clearneeded then
                    unmatchedCloses = {}
                end
                
            end
            local text = string.sub(input, currentToken.Start, currentToken.End)
            local node = {
                text = text,
                firstToken = currentToken,
                children = {},
                properties = {},
            }
            table.insert(openNodes[#openNodes].children, node)
            goto finishTokenLoop
        elseif tType == LexerTokenTypes.OpenMarker then
            -- we hit an open marker
            -- we first want to see if this is part of a close marker
            -- if it is then we can just wrap up the current root (or roots in the case of close all)
            if comparePattern(tokens, tokenIndex, closeAllPattern) then
                -- it's the close all marker
                -- in this case though all we need to do though is just remove the stack from the list as we go through it
                tokenIndex = tokenIndex + 2 -- equivilant to stream.Consume(2)
                while #openNodes > 1 do
                    local markupTreeNode = table.remove(openNodes)
                    if markupTreeNode.name ~= nil then
                        for i, value in ipairs(unmatchedCloses) do
                            if value == markupTreeNode.name then
                                table.remove(unmatchedCloses, i)
                                break
                            end
                        end
                    end
                end
                for _, unmatched in ipairs(unmatchedCloses) do
                    table.insert(diagnostic, {message = "Asked to close ".. unmatched .." markup but there is no corresponding opening. Is [/".. unmatched .."] a typo?", column = 0})
                end
                unmatchedCloses = {}
                goto finishTokenLoop
            elseif comparePattern(tokens, tokenIndex, closeOpenAttributePattern) then
                -- it's a close an open attribute marker
                local closeIDToken = tokens[tokenIndex + 2]
                local closeID = string.sub(input, closeIDToken.Start, closeIDToken.End)
                -- eat the tokens we compared
                tokenIndex = tokenIndex + 3
                currentToken = tokens[tokenIndex]
                -- ok now we need to work out what we do if they don't match
                -- first up we need to get the current top of the stack
                if #openNodes == 1 then
                    -- this is an error, we can't close something when we only have the root node
                    table.insert(diagnostic, {message = "Asked to close " .. closeID .. ", but we don't have an open marker for it.", column = currentToken.Start})
                else
                    -- if they have the same name we are in luck
                    -- we can pop this bad boy off the stack right now and continue
                    -- if not then we add this to the list of unmatched closes for later clean up and continue
                    if(closeID == openNodes[#openNodes].name) then
                        table.remove(openNodes)
                    else
                        table.insert(unmatchedCloses, closeID)
                    end
                end
                goto finishTokenLoop
            elseif comparePattern(tokens, tokenIndex, closeErrorPattern) then
                local message = "Error parsing markup, detected invalid token ".. tokens[tokenIndex + 2].Type ..", following a close."
                table.insert(diagnostic, {message = message, column = currentToken.Start})
                goto finishTokenLoop
            end
            -- ok so now we are some variant of a regular open marker
            -- in that case we have to be one of:
            -- [ ID, [ ID =, [ nomarkup
            -- or an error of: [ *

            -- which means if the next token isn't an ID it's an error so let's handle that first  
            if tokens[tokenIndex+1].Type ~= LexerTokenTypes.Identifier then
                local message = "Error parsing markup, detected invalid token  " .. tokens[tokenIndex+1].Type .. ", following an open marker."
                table.insert(diagnostic, {message = message, column = currentToken.Start})
                goto finishTokenLoop
            end
            -- ok so now we are a valid form of an open marker
            -- but before we can continue we need to make sure that the tree is correctly closed off
            if #unmatchedCloses > 0 then
                local clearneeded = self:cleanUpUnmatchedCloses(openNodes, unmatchedCloses, diagnostic)
                if clearneeded then
                    unmatchedCloses = {}
                end
            end

            local idToken = tokens[tokenIndex + 1]
            local id = string.sub(input, idToken.Start, idToken.End)

            -- there are two slightly weird variants we will want to handle now
            -- the first is the nomarkup attribute, which completely changes the flow of the tool
            if comparePattern(tokens, tokenIndex, openAttributePropertyLessPattern) then
                if id == "nomarkup" then
                    --  so to get here we are [ nomarkup ]
                    -- which mean the first token after is 3 tokens away
                    local tokenStart = tokens[tokenIndex]
                    local firstTokenAfterNoMarkup = tokens[tokenIndex + 3] -- TODO double check if this should be 2 

                    -- we spin in here eating tokens until we hit closeOpenAttributePattern
                    -- when we do we stop and check if the id is nomarkupmarker
                    -- if it is we stop and return that
                    -- if we never find that we return an error instead
                    local nm = nil
                    while tokens[tokenIndex].Type ~= LexerTokenTypes.End do
                        if comparePattern(tokens, tokenIndex, closeOpenAttributePattern) then
                            --  [ / id ]
                            local nmIDToken = tokens[tokenIndex + 2]
                            if string.sub(input, nmIDToken.Start, nmIDToken.End) == "nomarkupmarker" then
                                -- we have found the end of the nomarkup marker
                                -- create a new text node
                                -- assign it as the child of the markup node
                                -- return this
                                local text = {
                                    text = string.sub(input, firstTokenAfterNoMarkup.Start, tokens[tokenIndex].End)
                                }
                                nm = {
                                    name = "nomarkup",
                                    firstToken = tokenStart,
                                    children = {text},
                                    properties = {},
                                }

                                --last step is to consume the tokens that represent [/nomarkup]
                                tokenIndex = tokenIndex + 3
                                break
                            end
                        end
                        tokenIndex = tokenIndex + 1
                    end
                    if nm == nil then
                        table.insert(diagnostic, {message = "we entered nomarkup mode but didn't find an exit token", column = tokenStart.Start})
                    else
                        table.insert(openNodes[#openNodes].children, nm)
                    end
                    goto finishTokenLoop
                else
                    -- we are a marker with no properties, [ ID ] the ideal case
                    local completeMarker = {
                        name = id,
                        firstToken = idToken,
                        children = {},
                        properties = {},
                    }
                    table.insert(openNodes[#openNodes].children, completeMarker)
                    table.insert(openNodes, completeMarker)
                    -- we now need to consume the id and ] tokens
                    tokenIndex = tokenIndex + 2
                    goto finishTokenLoop
                end


            end

            -- ok so we are now one of two options
            -- a regular open marker (best case): [ ID (ID = Value)+ ]
            -- or an open marker with a nameless property: [ (ID = Value)+ ]
            local marker = {
                name = id,
                firstToken = idToken,
                children = {},
                properties = {},
            }
            table.insert(openNodes[#openNodes].children, marker)
            table.insert(openNodes, marker)
            if tokens[tokenIndex + 2].Type ~= LexerTokenTypes.Equals then
                -- we are part of a normal [ID id = value] group
                -- we want to consume the [ and ID
                -- so that the next token in the stream will be clean to handle id = value triples.
                -- this way the [ ID = variant doesn't realise that it wasn't part of a normal [ ID id = value ] group
                tokenIndex = tokenIndex + 1
            end
            goto finishTokenLoop

        elseif tType == LexerTokenTypes.Identifier then
            -- ok so we are now at an identifier
            -- which is the situation we want to be in for properties of the form ID = VALUE
            -- in all situations its the same
            -- we get the id, use that to make a new property
            -- we get the value and coorce an actual value from it
            local id = string.sub(input, currentToken.Start, currentToken.End)
            if comparePattern(tokens, tokenIndex, numberPropertyPattern) then
                local value, valueString = TryNumberFromToken(input, tokens[tokenIndex + 2])
                if value == fail then
                    table.insert(diagnostic, {message = "failed to convert the value " .. valueString .. " into a valid property (expected number)", column = currentToken.Start})
                end
                openNodes[#openNodes].properties[id] =  value
            elseif comparePattern(tokens, tokenIndex, booleanPropertyPattern) then
                local value, valueString = TryBoolFromToken(input, tokens[tokenIndex + 2])
                if value == fail then
                    table.insert(diagnostic, {message = "failed to convert the value " .. valueString.. " into a valid property (expected boolean)", column = currentToken.Start})
                end
                openNodes[#openNodes].properties[id] =  value
            elseif comparePattern(tokens, tokenIndex, stringPropertyPattern) then
                local value = ValueFromToken(input, tokens[tokenIndex + 2])
                openNodes[#openNodes].properties[id] =  value
            elseif comparePattern(tokens, tokenIndex, interpolatedPropertyPattern) then
                -- don't actually know what type this is but let's just assume it's a string
                local value  = ValueFromInterpolatedToken(input, tokens[tokenIndex + 2])
                openNodes[#openNodes].properties[id] =  value
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
                local trimWhitespaceProp = top.properties.trimwhitespace
                if trimWhitespaceProp == nil then
                    top.properties.trimwhitespace =  true
                end
                tokenIndex = tokenIndex + 1 -- equivilant to stream.Consume(1)
            else
                -- we found a / but aren't part of a self closing marker
                -- at this stage this is now an error
                table.insert(diagnostic, {message = "Encountered an unexpected closing slash", column = currentToken.Start})
            end
        end
        :: finishTokenLoop ::
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

function LineParser:walkAndProcessTree(root, builder, attributes, localeCode, diagnostics)
        -- self.sibling keeps track of the last seen older sibling during tree walking.
        -- This is necessary to prevent a bug with "Yes... which I would have shown [emotion=\"frown\" /] had [b]you[/b] not interrupted me."
        -- where the b tag is a rewriter and the emotion tag is not.
        -- in that case because previously we only kept the last fully processed non-replacement sibling the emotion tag would eat the whitespace AFTER the b tag had replaced itself
    self.sibling = nil
    self:walkTree(root, builder, attributes, localeCode, diagnostics, 0)
end

function LineParser:walkTree(root, builder, attributes, localeCode, diagnostics, offset)
    if offset == nil then
        offset = 0
    end
    local line = root.text
    if line ~= nil then
        -- if we are a text node
        if self.sibling ~= nil then
            -- and we have an older sibling
            local trimWhitespace = self.sibling.properties.trimwhitespace
            if trimWhitespace then
                if #line > 0 and string.match(line, "%s") then
                    line = string.sub(line, 2) -- trim the first character
                end
            end
        end
        -- finally if there are any escaped markup in the line we need to clean them up also
        line = string.gsub(line, "\\%[", "[")
        line = string.gsub(line, "\\%]", "]")
        -- then we add ourselves to the growing line
        builder[1] = builder[1] .. line
        -- and make ourselve the new older sibling
        self.sibling = root
        return
    end

    -- we aren't text so we will need to handle all our children
    -- we do this recursively
    local childBuilder = {""}
    local childAttributes = {}
    for _, child in ipairs(root.children) do
        self:walkTree(child, childBuilder, childAttributes, localeCode, diagnostics, #(builder[1]) + offset)
    end
    -- before we go any further if we are the root node that means we have finished and can just wrap up
    if root.name == nil then
        -- we are so we have nothing left to do, just add our children and be done
        builder[1] = builder[1] .. childBuilder[1]
        table.move(childAttributes, 1, #childAttributes, #attributes + 1, attributes)
        return
    end

    -- finally now our children have done their stuff so we can run our own rewriter if necessary
    -- to do that we will need the combined finished string of all our children and their attributes   
    local rewriter = self.markerProcessors[root.name]
    if rewriter ~= nil then
        -- we now need to do the rewrite
        -- so in this case we need to give the rewriter the combined child string and it's attributes
        -- because it is up to you to fix any attributes if you modify them
        -- TODO this is probably messed up. No null handling for root.first token 
        local attribute = MarkupAttribute(#(builder[1]) + offset, root.firstToken.Start, #(childBuilder[1]), root.name, root.properties)
        local newDiagnostics = rewriter:ProcessReplacementMarker(attribute, childBuilder, childAttributes, localeCode)
        table.move(newDiagnostics, 1, #newDiagnostics, #diagnostics + 1, diagnostics)
    else
        -- we aren't a replacement marker
        -- which means we need to add ourselves as a tag
        -- the source position one is easy enough, that is just the position of the first token (wait you never added these you dingus)
        -- we know the length of all the children text because of the childBuilder so that gives us our range
        -- and we know our relative start because of our siblings text in the builder
        local attribute = MarkupAttribute(#(builder[1]) + offset, root.firstToken.Start, #(childBuilder[1]), root.name, root.properties)
        table.insert(attributes, attribute)
    end

    -- ok now at this stage inside childBuilder we have a valid modified (if was necessary) string
    -- and our attributes have been added, all we need to do is add this to our siblings and continue
    builder[1] = builder[1] .. childBuilder[1]
    table.move(childAttributes, 1, #childAttributes, #attributes + 1, attributes);

    -- finally we make ourselves the most immediate oldest sibling
    self.sibling = root;
end

function LineParser:SquishSplitAttributes(attributes)
        -- grab every attribute that has a _internalIncrementingProperty property
        -- then for every attribute with the same value of that property we merge them
        -- and finally remove the _internalIncrementingProperty property
        local removals = {}
        local merged = {}
        for i, attribute in ipairs(attributes) do
            local value = attribute.Properties["_internalIncrementingProperty"]
            if value ~= nil then
                local existingAttribute = merged[value]
                if existingAttribute ~= nil then
                    if existingAttribute.Position > attribute.Position then
                        existingAttribute.Position = attribute.Position
                    end
                    existingAttribute.Length = existingAttribute.Length + attribute.Length
                    merged[value] = existingAttribute
                else
                    merged[value] = attribute
                end
                table.insert(removals, i)
            end
        end
        -- now we need to remove all the ones with _internalIncrementingProperty
        table.sort(removals)
        for i = #removals, 1, -1 do
            table.remove(attributes, removals[i])
        end
        -- and add our merged attributes back in
        for _, value in pairs(merged) do
            table.insert(attributes, value)
        end
end


function LineParser:ParseString(input, localeCode, addImplicitCharacterAttribute)
    local squish = true
    local sort = true
    local addImplicitCharacterAttribute = addImplicitCharacterAttribute ~= false
    assert(type(input) == "string", "input must be a string")
    -- TODO think about unicode normalization
    local tokens = self:lexMarkup(input)
    local parseResult, diagnostics = self:buildMarkupTreeFromTokens(tokens, input)

    if #diagnostics > 0 then
        -- ok so at this point if parseResult.diagnostics is not empty we have lexing/parsing errors
        -- it makes no sense to continue, just set the text to be the input so something exists
        return {text = input, attributes = {}}, diagnostics
    end
    local builder = {""}
    local attributes = {}

    self:walkAndProcessTree(parseResult, builder, attributes, localeCode, diagnostics)

    if squish then
        self:SquishSplitAttributes(attributes)
    end

    local finalText = table.concat(builder)
    print(finalText)

    if addImplicitCharacterAttribute then
        local hasCharacterAttributeAlready = false
        for _, attribute in ipairs(attributes) do
            if attribute.Name == "character" then
                hasCharacterAttributeAlready = true
                break
            end
        end
        if not hasCharacterAttributeAlready then
            local characterMatch = string.match(finalText, "^[^:]*:%s*")
            if characterMatch ~= nil then
                local colonIndex = string.find(characterMatch, ":")
                local characterName = string.sub(characterMatch, 1, colonIndex - 1)
                local characterAttribute = MarkupAttribute(0, 0, #characterMatch, "character", {name = "name", value = characterName})
                table.insert(attributes, characterAttribute)
            end
        end
    end

    if(sort) then
        table.sort(attributes, function(a, b)
            return a.SourcePosition < b.SourcePosition
        end)
    end

    return {
        text = finalText,
        attributes = attributes
    }, diagnostics
end
function LineParser:RegisterMarkerProcessor(attributeName, markerProcessor)
   assert(type(attributeName) == "string", "attributeName must be a string")
   assert(type(markerProcessor.ProcessReplacementMarker) == "function", "markerProcessor:ProcessReplacementMarker must be a function")
   assert(self.markerProcessors[attributeName] == nil, "A marker processor for ".. attributeName .. " has already been registered.")
   self.markerProcessors[attributeName] = markerProcessor
end

function LineParser:DeregisterMarkerProcessor(attributeName)
   self.markerProcessors[attributeName] = nil
end