import 'CoreLibs/object'
import 'libraries/playline/modules/ActionMarkupHandlerBase.lua'

Playline = Playline or {}
Playline.Defaults = Playline.Defaults or {}

Playline.Defaults.PauseActionMarkupHandler = {}
class('PauseActionMarkupHandler', nil, Playline.Defaults).extends(Playline.ActionMarkupHandlerBase)
function Playline.Defaults.PauseActionMarkupHandler:init(defaultPauseDuration, skipPausesIfHurrying)
    Playline.Defaults.PauseActionMarkupHandler.super.init(self)
    self.defaultPauseDuration = defaultPauseDuration or 250
    self.pauseAttributes = {}
    self.processIndex = 1
    self.skipPausesIfHurrying = skipPausesIfHurrying or false
end

function Playline.Defaults.PauseActionMarkupHandler:OnLineDisplayBegin(lineInfo)
   self.pauseAttributes = self:GetAllMarkupByName("pause", lineInfo)
   self.processIndex = 1
end

function Playline.Defaults.PauseActionMarkupHandler:OnCharacterWillAppear(characterIndex, lineInfo, lineCancellationToken, modifyLineSpeedFn)
    if self.skipPausesIfHurrying and lineCancellationToken.HurryUpToken then
        return nil
    end
    local pauses = {}
    while self.processIndex <= #self.pauseAttributes do
        local attribute = self.pauseAttributes[self.processIndex]
        if characterIndex == attribute.Position then
            table.insert(pauses, self:handlePause(attribute, lineCancellationToken))
            self.processIndex += 1
        else
            break
        end
    end

    if #pauses == 1 then
        return pauses[1]  -- Return the single pause coroutine directly
    end

    if #pauses > 1 then
        return coroutine.create(function()
            for _, pauseCoroutine in ipairs(pauses) do
                while coroutine.status(pauseCoroutine) ~= "dead" do
                    coroutine.resume(pauseCoroutine, lineCancellationToken)
                    coroutine.yield()
                end
            end
        end)
    end
end

function Playline.Defaults.PauseActionMarkupHandler:handlePause(pauseAttribute, lineCancellationToken)
    local pauseDuration = tonumber(pauseAttribute.Properties["pause"] or self.defaultPauseDuration)
    return coroutine.create(function()
        local startTime = playdate.getCurrentTimeMilliseconds()
        while (playdate.getCurrentTimeMilliseconds() - startTime) < pauseDuration and
         not (self.skipPausesIfHurrying and lineCancellationToken.HurryUpToken) do
            coroutine.yield()
        end
    end)
end