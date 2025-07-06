import 'CoreLibs/object'

Playline = Playline or {}
Playline.Saliency = Playline.Saliency or {}
Playline.FirstSaliencyStrategy = {}
class('FirstSaliencyStrategy', nil, Playline.Saliency).extends()


function Playline.FirstSaliencyStrategy:init()
end

function Playline.FirstSaliencyStrategy:ContentWasSelected(_)
    -- This strategy does not need need to track any state, so this method doesn't do anything.
end

function Playline.FirstSaliencyStrategy:QueryBestContent(options)
    for _, option in ipairs(options) do
        if option.failingConditionValueCount == 0 then
            return option
        end
    end

    return nil
end