import "CoreLibs/object"
import 'libraries/playline/modules/lineParser.lua'
import 'libraries/playline/utilities/NumberPlurals.lua'
import "utils.lua"

Playline = Playline or {}
local pu <const> = Playline.Utils

local pluralRewritter = {}
local ordinalRewritter = {}
local selectRewritter = {}

Playline.LineProvider = {}
class('LineProvider', nil, Playline).extends()
function Playline.LineProvider:init(lineStorage, metadata, useBuiltInMarkerProcessors)
    self.LocaleCode = "en" -- placeholder until I think through how localization will work
    self.lineStorage = lineStorage
    self.metadata = metadata
    self.lineParser = LineParser()

    if useBuiltInMarkerProcessors or useBuiltInMarkerProcessors == nil then
        self:RegisterMarkerProcessor("plural", pluralRewritter)
        self:RegisterMarkerProcessor("ordinal", ordinalRewritter)
        self:RegisterMarkerProcessor("select", selectRewritter)
    end
end

function Playline.LineProvider:ExpandSubstitutions(text, substitutions)
    if #substitutions > 0 then
        for k,v in ipairs(substitutions) do
            text = string.gsub(text, "{"..(k-1).."}", tostring(v));
        end
    end
    return text;
end

function Playline.LineProvider:GetLine(lineId, substitutions)
    local metadata = self.metadata[lineId] or {}
    local shadowLineId = pu.GetLineMetadataTagValue(metadata, "shadow")

    if shadowLineId then
       lineId = "line:" .. shadowLineId
    end

    local lineText = self.lineStorage[lineId]
    local expandedText = self:ExpandSubstitutions(lineText, substitutions)
    local parseResult = self.lineParser:ParseString(expandedText, "en", metadata)
    local text = parseResult.text
    local attributes = parseResult.attributes
    return {
        text = text,
        attributes = attributes,
        rawText = lineText,
        textId = lineId,
        metadata = metadata,
    }
end

function Playline.LineProvider:RegisterMarkerProcessor(markerName, rewritter)
    self.lineParser:RegisterMarkerProcessor(markerName, rewritter)
end

function Playline.LineProvider:DeregisterMarkerProcessor(markerName)
    self.lineParser:DeregisterMarkerProcessor(markerName)
end

local function replaceUnescapedPercent(replacement, originalValue)
    local res = replacement:gsub("([^\\])%%", function(a) return a .. originalValue end)
    if replacement:sub(1,1) == "%" then
        res = originalValue .. res:sub(2)
    end
    return res
end

function pluralRewritter:ProcessReplacementMarker(attribute, stringWrapper, childAttributes, localeCode)
    local value  = attribute.Properties.value
    local numericValue = tonumber(value)
    if not numericValue then
        return {{message = "Plural markup rewriting failed, value: ".. value .. "not convertable to a number", column = attribute.SourcePosition}}
    end
    local pluralCase = GetCardinalPluralCase(localeCode, numericValue)
    local replacement = attribute.Properties[pluralCase]
    if not replacement then
        return {{message = "No replacement found for case: " .. pluralCase, column = attribute.SourcePosition}}
    end
    stringWrapper[1] = replaceUnescapedPercent(replacement, value)
    return {}
end

function ordinalRewritter:ProcessReplacementMarker(attribute, stringWrapper, childAttributes, localeCode)
    local value  = attribute.Properties.value
    local numericValue = tonumber(value)
    if not numericValue then
        return {{message = "Ordinal markup rewriting failed, value: ".. value .. "not convertable to a number", column = attribute.SourcePosition}}
    end
    local ordinalCase = GetOrdinalPluralCase(localeCode, numericValue)
    local replacement = attribute.Properties[ordinalCase]
    if not replacement then
        return {{message = "No replacement found for case: " .. ordinalCase, column = attribute.SourcePosition}}
    end
    stringWrapper[1] = replaceUnescapedPercent(replacement, value)
    return {}
end

function selectRewritter:ProcessReplacementMarker(attribute, stringWrapper, childAttributes, localeCode)
    local value  = attribute.Properties.value
    local replacement = attribute.Properties[tostring(value)]
    if not replacement then
        return {{message = "No replacement found for case: " .. value, column = attribute.SourcePosition}}
    end

    stringWrapper[1] = replaceUnescapedPercent(replacement, value)
    return {}
end