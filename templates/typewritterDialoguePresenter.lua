import 'CoreLibs/object'
import 'CoreLibs/graphics'

import 'libraries/playline/modules/dialoguePresenterBase.lua'
import 'libraries/playline/modules/utils.lua'

local gfx <const> = playdate.graphics

Playline = Playline or {}
Playline.Defaults = Playline.Defaults or {}
local pu <const> = Playline.Utils

local function convertCpsToSpc(charactersPerSecond)
    return 1.0 / charactersPerSecond;
end



class('TypewritterDialoguePresenter', nil, Playline.Defaults).extends(Playline.DialoguePresenterBase)
function Playline.Defaults.TypewritterDialoguePresenter:init(textImage, onStart, charactersPerSecond, textBackground)
    Playline.Defaults.TypewritterDialoguePresenter.super.init(self)
    self.textImage = textImage
    self.textBackground = textBackground
    self.onStart = onStart or function() end
    self.inProgressCoroutines = {}
    self.ActionMarkupHandlers = {}
    self.CharactersPerSecond = charactersPerSecond or 15
    local width, height = textImage:getSize()
    self.textImageRect = playdate.geometry.rect.new(10, 10, width-15, height-20)
    self.textBackgroundRect = playdate.geometry.rect.new(0, 0, width, height)

end

function Playline.Defaults.TypewritterDialoguePresenter:writeToImage(lineText, charsToShow)
    local writableLine = lineText:sub(1, charsToShow)
    print("Typewritter: " .. writableLine)
    self.textImage:clear(gfx.kColorClear)
    gfx.pushContext(self.textImage)
    self.textBackground:drawInRect(self.textBackgroundRect)
    gfx.setImageDrawMode(playdate.graphics.kDrawModeFillBlack)
    gfx.drawText(writableLine, self.textImageRect)
    gfx.popContext()
end

function Playline.Defaults.TypewritterDialoguePresenter:RunLine(lineInfo)
    -- This method can be overridden by subclasses to handle lines
    -- For example, you could implement a typewriter effect here
    print("Running line: " .. lineInfo.text)
    self.onStart()
    self.textImage:clear(gfx.kColorClear)
    local line = lineInfo.text
    local lineSecondsPerCharacter = convertCpsToSpc(self.CharactersPerSecond)
    local modifyLineSpeedFn = function(cps)
        if cps then
            lineSecondsPerCharacter = convertCpsToSpc(cps)
        else
            lineSecondsPerCharacter = convertCpsToSpc(self.CharactersPerSecond)
        end
    end
    if line then
        return coroutine.create(function(lineCancellationToken)
            local i = 1
            -- Start with a full time budget so that we immediately show the first character
            local accumulatedDelay = lineSecondsPerCharacter;
            for _, action in ipairs(self.ActionMarkupHandlers) do
                action:OnLineDisplayBegin(lineInfo)
            end

            while i <= #line do
                while(not lineCancellationToken.HurryUpToken
                    and accumulatedDelay < lineSecondsPerCharacter) do
                        local timeBeforeYield = playdate.getCurrentTimeMilliseconds()
                        coroutine.yield()
                        local timeAfterYield = playdate.getCurrentTimeMilliseconds()
                        accumulatedDelay += (timeAfterYield - timeBeforeYield) / 1000 -- convert to seconds
                end

                for _, action in ipairs(self.ActionMarkupHandlers) do
                    local actionResult = action:OnCharacterWillAppear(i, lineInfo, lineCancellationToken, modifyLineSpeedFn)
                    if type(actionResult) == "thread" then
                        table.insert(self.inProgressCoroutines, actionResult)
                    end
                end

                pu.ResumeThreadsAndYieldUntilAllDead(self.inProgressCoroutines, {lineCancellationToken})

                self:writeToImage(line, i)
                
                accumulatedDelay -= lineSecondsPerCharacter;
                i += 1
            end
            self:writeToImage(line, #line)
            lineCancellationToken.HurryUpToken = true
            coroutine.yield()
        end)
    end
end

function Playline.Defaults.TypewritterDialoguePresenter:AddActionMarkupHandler(handler)
    table.insert(self.ActionMarkupHandlers, handler)
end
