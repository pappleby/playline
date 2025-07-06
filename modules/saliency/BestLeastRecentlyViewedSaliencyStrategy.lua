import 'CoreLibs/object'
import 'libraries/playline/modules/utils.lua' -- really wish I could import from one level higher
Playline = Playline or {}
local pu <const> = Playline.Utils

Playline.Saliency = Playline.Saliency or {}
Playline.BestLeastRecentlyViewedSaliencyStrategy = {}
class('BestLeastRecentlyViewedSaliencyStrategy', nil, Playline.Saliency).extends()


function Playline.Saliency.BestLeastRecentlyViewedSaliencyStrategy:init(variableAccess, isRandomTieBreaker)
    self.variableAccess = variableAccess
    if isRandomTieBreaker then
        self.getSortTieBreaker = function(_, optionCount) return math.random(optionCount)
        end
    else
        self.getSortTieBreaker = function(index, _) return index end
    end
end

function Playline.Saliency.BestLeastRecentlyViewedSaliencyStrategy:ContentWasSelected(option)
    local viewCountKey = pu.GetSaliencyViewCountKey(option.contentId)
    local viewCount = self.variableAccess:Get(viewCountKey) or 0
    viewCount += 1
    self.variableAccess:Set(viewCountKey, viewCount)
end

function Playline.Saliency.BestLeastRecentlyViewedSaliencyStrategy:QueryBestContent(options)
    local passingOptions = {}

    for originalIndex, option in ipairs(options) do
        if option.failingConditionValueCount == 0 then
            table.insert(passingOptions, {
                option = option,
                viewCount = self.variableAccess:Get(pu.GetSaliencyViewCountKey(option.contentId)) or 0,
                sortTieBreaker = self.getSortTieBreaker(originalIndex, #options)
            })
        end
    end
    if #passingOptions == 0 then
        return nil
    end

    table.sort(passingOptions, function(a, b)
        if a.option.complexityScore == b.option.complexityScore then
            if a.viewCount == b.viewCount then
                return a.sortTieBreaker < b.sortTieBreaker
            end
            return a.viewCount < b.viewCount
        end
        return a.option.complexityScore > b.option.complexityScore
    end
)

    return passingOptions[1].option
end