import 'CoreLibs/object'
import 'CoreLibs/string'
import 'library.lua'
import 'vm.lua'
Playline = Playline or {}

Playline.Dialogue = {}
---@class Dialogue
class('Dialogue', nil, Playline).extends()
function Playline.Dialogue:init(variableStorage, yarnProgram, lineProvider)
    self.library = Playline.Library(true)
    self.program = yarnProgram
    self.variableStorage = variableStorage
    self.lineProvider = lineProvider
    variableStorage.smartVariableEvaluator = self
    self.vm = VM(self.library, yarnProgram, variableStorage)
    self.smartVariableVM = {} -- Placeholder for smart variable VM
    self.library:registerFunction("visited", function(nodeName)
        self:IsNodeVisited(nodeName)
    end)
    self.library:registerFunction("visited_count", function(nodeName)
        self:GetNodeVisitCount(nodeName)
    end)
    self.coroutineRunning = nil
    self.dialoguePresenters = {}
    self.vm.lineHandler = function(...) self:handleLine(...) end
end

function Playline.Dialogue:handleLine(lineId, substitutions)
    local lineInfo = self.lineProvider:GetLine(lineId, substitutions)
    for _, presenter in ipairs(self.dialoguePresenters) do
        presenter:RunLine(lineInfo)
    end
end

function Playline.Dialogue:AddDialoguePresenter(presenter)
    table.insert(self.dialoguePresenters, presenter)
end

function Playline.Dialogue:SetOptionsHandler(optionsHandler)
    self.vm.optionsHandler = optionsHandler
end

function Playline.Dialogue:SetCommandHandler(commandHandler)
    self.vm.commandHandler = commandHandler
end

function Playline.Dialogue:GetNodeVisitCount(nodeName)
    local variableName = GenerateUniqueVisitedVariableForNode(nodeName)
    local count = self.variableStorage:getVariable(variableName) or 0
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
    local node = self.program.nodes[nodeName]
    assert(node, "Node '" .. nodeName .. "' not found in program.")
    for key,value in pairs(node.headers) do
        if key == headerName then
            return playdate.string.trimWhitespace(value)
        end
    end
end

function Playline.Dialogue:GetSaliencyOptionsForNodeGroup(nodeGroupName)
    ---Not implemented yet
    assert(false, "GetSaliencyOptionsForNodeGroup is not implemented yet.")
    return {}
end

function Playline.Dialogue:AddCommandHandler(commandName, commandFunction)
    assert(self.library, "Library is not initialized.")
    self.library:registerCommand(commandName, commandFunction)
end
