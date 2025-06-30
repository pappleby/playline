import 'libraries/playline/modules/dialogue.lua'
import 'libraries/playline/modules/utils.lua'
import 'libraries/playline/modules/lineProvider.lua'

function string.formatcs(str, substitutions)
	if #substitutions > 0 then
		for k,v in ipairs(substitutions) do
			str = string.gsub(str, "{"..(k-1).."}", tostring(v));
		end
	end
	return str;
end
local variableStorage = {}
local lineStorage = playdate.datastore.read('assets//data//playline//stringtable')
local metadata = playdate.datastore.read('assets//data//playline//metadata')
local yarnProgram = playdate.datastore.read('assets//data//playline//yarnprogram')
local lineOutput = ''
local optionsOutput = {}
local lineProvider = Playline.LineProvider(lineStorage, metadata, true)
local boldRewritter = {
    ProcessReplacementMarker = function(rewritter, attribute, childBuilder, childAttributes, localeCode)
        print("Processing bold marker with attribute: ")
        childBuilder[1] = string.format("*%s*", childBuilder[1])
        return {}
    end,
}
local italicRewritter = {
    ProcessReplacementMarker = function(rewritter, attribute, childBuilder, childAttributes, localeCode)
        print("Processing italic marker with attribute: ")
        childBuilder[1] = string.format("_%s_", childBuilder[1])
        return {}
    end,
}
lineProvider:RegisterMarkerProcessor("bold", boldRewritter)
lineProvider:RegisterMarkerProcessor("italic", italicRewritter)

MyStory = Playline.Dialogue(variableStorage, yarnProgram, lineProvider)
MyStory:AddCommandHandler("test_command", function(...)
    local debugOutput = "Test command executed with arguments: "
    for i, v in ipairs({...}) do
        debugOutput = debugOutput .. i .. ": " .. tostring(v) .. ", "
    end
    print(debugOutput)
end)

MyStory.DefaultOptionsHandler = function(options)
    optionsOutput = {}
    assert(lineStorage ~= nil, "Line storage is not initialized.")
    for i, option in ipairs(options) do
        local optionTextInfo = lineProvider:GetLine(option.lineId, option.substitutions)
        local formattedOptionText = optionTextInfo.text
        optionsOutput[i] = {
            text = (formattedOptionText),
            index = i,
            enabled = option.enabled}
    end
    return optionsOutput
end

-- should this get moved into dialogue.lua as a default command handler?
MyStory:SetCommandHandler(function(command, library)
    local parsedCommand = SplitCommandText(command)
    local commandFunction = library.commands[parsedCommand.name]
    assert(commandFunction, "Command '" .. parsedCommand.name .. "' not found in library.")

    local result = commandFunction(table.unpack(parsedCommand.params))
    if type(result) == "thread" then
        local wrapper = coroutine.wrap(function()
            while coroutine.status(result) ~= "dead" do
                coroutine.resume(result)
                coroutine.yield()
            end
            MyStory:FinishCoroutine()
        end)
        MyStory:SetCoroutineRunning(wrapper)
    else
        MyStory:Continue()
    end
end)

function MyStory:GetCurrentLine()
    return lineOutput
end

function MyStory:GetCurrentOptions()
    return optionsOutput
end
