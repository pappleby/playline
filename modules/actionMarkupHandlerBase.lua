import "CoreLibs/object"

Playline = Playline or {}
Playline.ActionMarkupHandlerBase = {}
class('ActionMarkupHandlerBase', nil, Playline).extends()

function Playline.ActionMarkupHandlerBase:init()
end

function Playline.ActionMarkupHandlerBase:OnLineDisplayBegin(lineInfo)
    return nil
end

function Playline.ActionMarkupHandlerBase:OnCharacterWillAppear(characterIndex, lineInfo, lineCancellationToken, attributesStartingNow, modifyLineSpeedFn)
    -- Return a coroutine if you want to delay the next character's appearance until the coroutine is completed
    return nil
end

function Playline.ActionMarkupHandlerBase:OnLineDisplayComplete()
    return nil
end

function Playline.ActionMarkupHandlerBase:GetAllMarkupByName(name, lineInfo)
    local result = {}
    for _, attribute in ipairs(lineInfo.attributes) do
        if attribute.Name == name then
            table.insert(result, attribute)
        end
    end
    return result
end