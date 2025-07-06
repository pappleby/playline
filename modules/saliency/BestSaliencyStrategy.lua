import 'CoreLibs/object'

Playline = Playline or {}
Playline.Saliency = Playline.Saliency or {}
Playline.BestSaliencyStrategy = {}
class('BestSaliencyStrategy', nil, Playline.Saliency).extends()


function Playline.BestSaliencyStrategy:init()
end

function Playline.BestSaliencyStrategy:ContentWasSelected(_)
    -- This strategy does not need need to track any state, so this method doesn't do anything.
end

function Playline.BestSaliencyStrategy:QueryBestContent(options)
    local highestcomplexityScore = -1
    local bestOptionSoFar = nil
    for _, option in ipairs(options) do
        if option.failingConditionValueCount == 0 then
            if bestOptionSoFar == nil or option.complexityScore > highestcomplexityScore then
                highestcomplexityScore = option.complexityScore
                bestOptionSoFar = option
            end
        end
    end

    return bestOptionSoFar
end