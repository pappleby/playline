function SplitCommandText(commandText)
   local c = nil
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
   local readIndex = 1
   local peek = function()
        -- Read a single character from the command text, nil if we reach the end.
        if(readIndex > #commandText) then
            return nil
        end
        local char = commandText:sub(readIndex, readIndex)
        return char
   end
   local read = function()
        c = peek()
        if c == nil then
            return nil
        end
        readIndex = readIndex + 1
        return c
    end

    
    while (read()) ~= nil do
        ---@diagnostic disable-next-line: param-type-mismatch
        if c == string.match(c, '%s') then
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
                read()
                if c == nil then
                    -- Oops, we ended the input while parsing a quoted
                    -- string! Dump our current word immediately and return.
                    addNameOrParam(currentComponent)
                    return results
                elseif c == '\\' then
                    -- Possibly an escaped character!
                    local next = peek()
                    if (next == '\\' or next == '"') then
                        -- It is! Skip the \ and use the character after it.
                        read() -- Skip the escape character
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