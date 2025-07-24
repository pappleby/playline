import "CoreLibs/object"
Playline = Playline or {}
Playline.Utils = Playline.Utils or {}
local pu <const> = Playline.Utils

pu.StringHelper = {
    IsDigit = function(c)
        return c ~= nil and c == string.match(c, '%d')
    end,
    IsLetterOrDigit = function(c)
        return c ~= nil and c == string.match(c, '%w')
    end,
    IsWhitespace = function(c)
        return c ~= nil and c == string.match(c, '%s')
    end,
    IsBoolean = function(c)
        return c ~= nil and (c == 'true' or c == 'false')
    end,
    FindEndOfAlphanumeric = function(input, startIndex)
        local _, endIndex = input:find('^%w+', startIndex)
        return endIndex
    end,
    FindEndOfCurlyBraces = function(input, startIndex)
        local _, endIndex = input:find('}', startIndex)
        return endIndex
    end,
    FindEndOfQuotedString = function(input, startIndex)
        startIndex = startIndex
        while true do
            local quotePos = input:find('"', startIndex + 1) -- skip the opening quote
            if not quotePos then return nil end
            local bsStart, bsEnd = input:find("\\*$", startIndex, quotePos - 1)
            local bsCount = 0
            if bsStart and bsEnd then
                bsCount = bsEnd - bsStart + 1
            end
            if bsCount % 2 == 0 then
                return quotePos
            end
            startIndex = quotePos + 1
        end
    end,
    FindEndOfNumber = function(input, startIndex)
        local _, endIndex = input:find('^-?%d+', startIndex)
        local _, endDecimalIndex = input:find('^%.%d+', endIndex + 1)
        if endDecimalIndex ~= nil then
            endIndex = endDecimalIndex
        end
        return endIndex
    end,
}
pu.StringReader = {}
class('StringReader', nil, pu).extends()
function pu.StringReader:init(input, output)
    self.input = input
    self.readIndex = 1
    self.output = output or {}
end

function pu.StringReader:Peek()
    local text = self.input
    local readIndex = self.readIndex
    -- Read a single character from the text, nil if we reach the end.
    if (readIndex > #text) then
        return nil
    end
    local char = text:sub(readIndex, readIndex)
    self.output[1] = char
    return char
end

function pu.StringReader:Read()
    local c = self:Peek() -- This also updates the output
    if c == nil then
        return nil
    end
    self.readIndex = self.readIndex + 1
    return c
end

function pu.StringReader:SkipPastIndex(index)
    self.readIndex = index + 1
end

function pu.SplitCommandText(commandText)
    local results = {
        name = nil,
        params = {}
    }
    local addNameOrParam = function(value)
        if results.name == nil then
            results.name = value
        else
            table.insert(results.params, value)
        end
    end
    local currentComponent = ''
    local readerOutput = { nil }
    local reader = pu.StringReader(commandText, readerOutput)

    while (reader:Read()) ~= nil do
        local c = readerOutput[1] -- Get the character read by the reader
        ---@diagnostic disable-next-line: param-type-mismatch
        if pu.StringHelper.IsWhitespace(c) then
            if #currentComponent > 0 then
                -- We've reached the end of a run of visible characters.
                -- Add this run to the result list and prepare for the next one.
                addNameOrParam(currentComponent)
                currentComponent = ''
            else
                -- We encountered a whitespace character, but didn't
                -- have any characters queued up. Skip this character.
                goto continue
            end
        elseif c == '"' then
            -- We've entered a quoted string!
            while true do
                c = reader:Read()
                if c == nil then
                    -- Oops, we ended the input while parsing a quoted
                    -- string! Dump our current word immediately and return.
                    addNameOrParam(currentComponent)
                    return results
                elseif c == '\\' then
                    -- Possibly an escaped character!
                    local next = reader:Peek()
                    if (next == '\\' or next == '"') then
                        -- It is! Skip the \ and use the character after it.
                        reader:Read() -- Skip the escape character
                        currentComponent = currentComponent .. next
                    else
                        -- Oops, an invalid escape. Add the \ and whatever is after it.
                        currentComponent = currentComponent .. c
                    end
                elseif c == '"' then
                    -- The end of a string!
                    goto finishQuotedString
                else
                    currentComponent = currentComponent .. c
                end
            end
            ::finishQuotedString::
            addNameOrParam(currentComponent)
            currentComponent = ''
        else
            currentComponent = currentComponent .. c
        end
        ::continue::
    end
    if #currentComponent > 0 then
        addNameOrParam(currentComponent)
    end
    return results
end

function pu.ResumeThreadsAndYieldUntilAllDead(threads, paramsArray)
    local runningThreadCount = #threads
    while runningThreadCount > 0 do
        runningThreadCount = 0
        for i = #threads, 1, -1 do
            local thread = threads[i]
            if coroutine.status(thread) ~= "dead" then
                local ok, err = coroutine.resume(thread, table.unpack(paramsArray or {}))
                if not ok then
                    print("Coroutine error:", err)
                end
                runningThreadCount += 1
            end
        end
        if runningThreadCount > 0 then
            coroutine.yield() -- Yield to allow other coroutines to run
        end
    end
end

function pu.GetNodeHeaderValue(node, headerName)
    if node and node.Headers then
        for _, header in ipairs(node.Headers) do
            if header.Key == headerName then
                return header.Value
            end
        end
    end
    return nil
end

function pu.GetLineMetadataTagValue(lineMetadata, key)
    local tags = lineMetadata.Tags
    if tags ~= nil then
        return tags[key]
    end
    return nil
end

function pu.GetContentSaliencyConditionVariables(node)
    local variablesString = pu.GetNodeHeaderValue(node, "$Yarn.Internal.ContentSaliencyVariables")
    if not variablesString or variablesString == "" then
        return {}
    end
    local variables = {}

    for part in string.gmatch(variablesString, "([^;]+)") do
        if part:len() ~= 0 then
            table.insert(variables, part)
        end
    end
    return variables
end

function pu.GetSaliencyViewCountKey(contentId)
    return "$Yarn.Internal.Content.ViewCount." .. contentId
end
