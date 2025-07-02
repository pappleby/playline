import 'CoreLibs/object'
import 'libraries/playline/modules/ActionMarkupHandlerBase.lua'

Playline = Playline or {}
Playline.Defaults = Playline.Defaults or {}

Playline.Defaults.BlipActionMarkupHandler = {}
class('BlipActionMarkupHandler', nil, Playline.Defaults).extends(Playline.ActionMarkupHandlerBase)
function Playline.Defaults.BlipActionMarkupHandler:init(defaultBlipPath, charToBlipPathLookup)
    Playline.Defaults.BlipActionMarkupHandler.super.init(self)
    local loadedblip, err = playdate.sound.sampleplayer.new(defaultBlipPath)
    if err then
        print("BlipActionMarkupHandler: error loading default blip sound: " .. tostring(err))
    else
        self.defaultBlipPlayers = {loadedblip, loadedblip:copy(), loadedblip:copy(), loadedblip:copy()}
    end
end

function Playline.Defaults.BlipActionMarkupHandler:OnLineDisplayBegin(lineInfo)
    -- maybe check for blip voices or character look up or tag to disable blips here?
    for _, player in ipairs(self.defaultBlipPlayers) do
        player:setRate(math.random(120, 130)*0.01) -- Randomize the playback rate between 120% and 130%
    end
end

function Playline.Defaults.BlipActionMarkupHandler:OnCharacterWillAppear(characterIndex, lineInfo, lineCancellationToken, modifyLineSpeedFn)
    if lineCancellationToken.HurryUpToken then
        return nil
    end
    if #self.defaultBlipPlayers > 0 and lineInfo.text:sub(characterIndex,characterIndex) ~= ' ' then
        local blipPlayer = self.defaultBlipPlayers[math.random(1, #self.defaultBlipPlayers)]
        if blipPlayer and not blipPlayer:isPlaying() then
            blipPlayer:play()
        end
    end
end
