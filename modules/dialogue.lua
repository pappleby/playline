import 'CoreLibs/object'
import 'CoreLibs/string'
import 'library.lua'
import 'vm.lua'
import 'smartVariableVM.lua'
import 'variableAccess.lua'
import 'saliency/RandomBestLeastRecentlyViewedSaliencyStrategy.lua'

Playline = Playline or {}
local pu <const> = Playline.Utils
local pi <const> = Playline.Internal

Playline.Dialogue = {}
---@class Dialogue
class('Dialogue', nil, Playline).extends()
function Playline.Dialogue:init(variableStorage, yarnProgram, lineProvider)
    self.library = Playline.Library(true)
    self.program = yarnProgram
    self.variableAccess = Playline.VariableAccess(variableStorage, yarnProgram, self.library)
    self.lineProvider = lineProvider
    self.saliencyStrategy = Playline.Saliency.RandomBestLeastRecentlyViewedSaliencyStrategy(self.variableAccess)
    self.vm = pi.VM(self.library, yarnProgram, self.variableAccess, self.saliencyStrategy)
    self.library:registerFunction("visited", function(nodeName)
        self:IsNodeVisited(nodeName)
    end)
    self.library:registerFunction("visited_count", function(nodeName)
        self:GetNodeVisitCount(nodeName)
    end)
    self.coroutineRunning = nil
    self.dialoguePresenters = {}
    self.vm.lineHandler = function(...) self:handleLine(...) end
    self.vm.commandHandler = function(...) self:handleCommand(...) end
    self.vm.optionsHandler = function(...) self:handleOptions(...) end
end

function Playline.Dialogue:handleLine(lineId, substitutions)
    local lineInfo = self.lineProvider:GetLine(lineId, substitutions)
    local runLineCoroutines = {}
    for _, presenter in ipairs(self.dialoguePresenters) do
        local runLineCoroutine = presenter:RunLine(lineInfo)
        if type(runLineCoroutine) == "thread" then
            table.insert(runLineCoroutines, runLineCoroutine)
        end
    end
    if #runLineCoroutines > 0 then
        local lineCancellationToken = {NextLineToken = false, HurryUpToken = false }
        local wrapper = coroutine.wrap(function()
            local firstTick = true
            local runningCoroutineCount = #runLineCoroutines
            while runningCoroutineCount > 0 do
                runningCoroutineCount = 0
                for _, runLineCoroutine in ipairs(runLineCoroutines) do
                    if coroutine.status(runLineCoroutine) ~= "dead" then
                        local ok, err = coroutine.resume(runLineCoroutine, lineCancellationToken)
                        if not ok then
                            print("Coroutine error:", err)
                        end
                        runningCoroutineCount += 1
                    end
                end
                if firstTick then
                    firstTick = false
                else
                   coroutine.yield()
                end
            end

            self:FinishCoroutine()
        end)
        self:SetCoroutineRunning(wrapper)
    end
end

function Playline.Dialogue:handleOptions(options)
    local optionsOutput = {}
    for i, option in ipairs(options) do
        local optionTextInfo = self.lineProvider:GetLine(option.lineId, option.substitutions)
        local formattedOptionText = optionTextInfo.text
        optionsOutput[i] = {
            text = (formattedOptionText),
            index = i,
            enabled = option.enabled}
    end

    for _, presenter in ipairs(self.dialoguePresenters) do
        if(presenter.RunOptions ~= nil) then
            -- For now don't support aysync options presenters
            -- TODO: Support async options presenters
            presenter:RunOptions(optionsOutput)
        end
    end
end

function Playline.Dialogue:AddDialoguePresenter(presenter)
    table.insert(self.dialoguePresenters, presenter)
end

function Playline.Dialogue:GetNodeVisitCount(nodeName)
    local variableName = GenerateUniqueVisitedVariableForNode(nodeName)
    local count = self.variableAccess:Get(variableName) or 0
    return count
end

function Playline.Dialogue:IsNodeVisited(nodeName)
    return self:GetNodeVisitCount(nodeName) > 0
end

function Playline.Dialogue:SetNode(nodeName)
    self.vm:SetNode(nodeName, true)
end

function Playline.Dialogue:SetSelectedOption(selectedOptionID)
    self.vm:SetSelectedOption(selectedOptionID);
end

function Playline.Dialogue:SetCoroutineRunning(coroutineRunning)
    self.coroutineRunning = coroutineRunning
end

function Playline.Dialogue:FinishCoroutine()
    self.coroutineRunning = nil
    self.vm:Continue()
end

function Playline.Dialogue:ProgressCoroutine()
    if self.coroutineRunning then
        self.coroutineRunning()
        return
    end
end

function Playline.Dialogue:Continue()
    if not self.vm.executionState == 'Running' or self.coroutineRunning then
        return
    end
    self.vm:Continue()
end

function Playline.Dialogue:Stop()
    self.vm:Stop()
end

function Playline.Dialogue:GetHeaderValue(nodeName, headerName)
    local node = self.program.Nodes[nodeName]
    assert(node, "Node '" .. nodeName .. "' not found in program.")
    for key,value in pairs(node.Headers) do
        if key == headerName then
            return playdate.string.trimWhitespace(value)
        end
    end
end

function Playline.Dialogue:GetSaliencyOptionsForNodeGroup(nodeGroupName)
    -- SmartVariableVM already has error handling, so no need to duplicate it here
    return Playline.SmartVariableVM.GetSaliencyOptionsForNodeGroup(nodeGroupName, self.variableAccess, self.program, self.library)
end

function Playline.Dialogue:RegisterCommand(commandName, commandFunction)
    assert(self.library, "Library is not initialized.")
    self.library:registerCommand(commandName, commandFunction)
end

function Playline.Dialogue:handleCommand(command, library)
    local parsedCommand = pu.SplitCommandText(command)
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
end

function Playline.Dialogue:OverrideCommandHandler(commandHandler)
    self.vm.commandHandler = commandHandler
end
