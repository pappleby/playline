import 'libraries/playline/modules/dialogue.lua'
import 'libraries/playline/modules/utils.lua'
import 'libraries/playline/modules/lineProvider.lua'

local variableStorage = {}
local lineStorage = playdate.datastore.read('assets//data//playline//stringtable')
local metadata = playdate.datastore.read('assets//data//playline//metadata')
local yarnProgram = playdate.datastore.read('assets//data//playline//yarnprogram')

local boldRewritter = {
    ProcessReplacementMarker = function(rewritter, attribute, stringWrapper, childAttributes, localeCode)
        print("Processing bold marker with attribute: ")
        stringWrapper[1] = string.format("*%s*", stringWrapper[1])
        return {}
    end,
}
local italicRewritter = {
    ProcessReplacementMarker = function(rewritter, attribute, stringWrapper, childAttributes, localeCode)
        print("Processing italic marker with attribute: ")
        stringWrapper[1] = string.format("_%s_", stringWrapper[1])
        return {}
    end,
}

-- TODO: consider moving into Playline.Dialogue (maybe as a default marker processor?)
local lineProvider = Playline.LineProvider(lineStorage, metadata, true)
lineProvider:RegisterMarkerProcessor("bold", boldRewritter)
lineProvider:RegisterMarkerProcessor("italic", italicRewritter)

MyStory = Playline.Dialogue(variableStorage, yarnProgram, lineProvider)
MyStory:RegisterCommand("test_command", function(...)
    local debugOutput = "Test command executed with arguments: "
    for i, v in ipairs({...}) do
        debugOutput = debugOutput .. i .. ": " .. tostring(v) .. ", "
    end
    print(debugOutput)
end)