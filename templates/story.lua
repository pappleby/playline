import 'libraries/playline/modules/dialogue.lua'
import 'libraries/playline/modules/utils.lua'

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

MyStory = Dialogue(variableStorage, yarnProgram)
MyStory.DefaultLineHandler = function(line, substitutions)
    print("Line: " .. line)

    assert(line ~= nil, "Line cannot be nil.")
    assert(lineStorage ~= nil, "Line storage is not initialized.")
    assert(lineStorage[line] or ("No line found for: " .. line))
    local lineText = lineStorage[line]
    local formattedLineText = string.formatcs(lineText, substitutions)
    lineOutput = formattedLineText
    return formattedLineText
end

MyStory.DefaultOptionsHandler = function(options)
    optionsOutput = {}
    assert(lineStorage ~= nil, "Line storage is not initialized.")
    for i, option in ipairs(options) do
        local optionText = lineStorage[option.lineId]
        assert(optionText or ("No line found for: " .. line))

        local formattedOptionText = string.formatcs(optionText, option.substitutions)
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
