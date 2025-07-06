import 'CoreLibs/object'
import 'BestLeastRecentlyViewedSaliencyStrategy.lua'

Playline = Playline or {}
Playline.Saliency = Playline.Saliency or {}
Playline.Saliency.RandomBestLeastRecentlyViewedSaliencyStrategy = {}
class('RandomBestLeastRecentlyViewedSaliencyStrategy', nil, Playline.Saliency).extends(Playline.Saliency.BestLeastRecentlyViewedSaliencyStrategy)
function Playline.Saliency.RandomBestLeastRecentlyViewedSaliencyStrategy:init(variableAccess)
    Playline.Saliency.RandomBestLeastRecentlyViewedSaliencyStrategy.super.init(self, variableAccess, true)
end