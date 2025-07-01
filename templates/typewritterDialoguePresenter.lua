import 'CoreLibs/object'
import 'CoreLibs/graphics'

import 'libraries/playline/modules/dialoguePresenterBase.lua'

local gfx <const> = playdate.graphics

Playline = Playline or {}
Playline.Defaults = Playline.Defaults or {}

class('TypewritterDialoguePresenter', nil, Playline.Defaults).extends(Playline.DialoguePresenterBase)
function Playline.Defaults.TypewritterDialoguePresenter:init(textImage, onStart)
    Playline.Defaults.TypewritterDialoguePresenter.super.init(self)
    self.textImage = textImage
    self.onStart = onStart or function() end

    local width, height = textImage:getSize()
    self.textImageRect = playdate.geometry.rect.new(0, 0, width, height)
end

function Playline.Defaults.TypewritterDialoguePresenter:writeToImage(lineText, charsToShow)
    local writableLine = lineText:sub(1, charsToShow)
    print("Typewritter: " .. writableLine)
    self.textImage:clear(gfx.kColorWhite)
    gfx.pushContext(self.textImage)
    gfx.setImageDrawMode(playdate.graphics.kDrawModeFillBlack)
    gfx.drawText(writableLine, self.textImageRect)
    gfx.popContext()
end

function Playline.Defaults.TypewritterDialoguePresenter:RunLine(lineInfo)
    -- This method can be overridden by subclasses to handle lines
    -- For example, you could implement a typewriter effect here
    print("Running line: " .. lineInfo.text)
    self.onStart()
    local line = lineInfo.text
    if line then
        return coroutine.create(function(lineCancellationToken)
            local i = 1
            while i <= #line do
                local startTime = playdate.getCurrentTimeMilliseconds()
                self:writeToImage(line, i)
                local ms = 60
                if lineCancellationToken.HurryUpToken then
                   break
                end
                while (not lineCancellationToken.HurryUpToken
                        and not lineCancellationToken.NextLineToken
                        and (playdate.getCurrentTimeMilliseconds() - startTime) < ms) do
                    lineCancellationToken = coroutine.yield()
                end
                i += 1
            end
            self:writeToImage(line, #line)
            lineCancellationToken.HurryUpToken = true
            coroutine.yield()
        end)
    end


end

