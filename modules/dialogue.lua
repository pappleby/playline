import 'CoreLibs/object'
import 'CoreLibs/string'
import 'library.lua'
import 'vm.lua'

---@class Dialogue
class('Dialogue').extends()
function Dialogue:init(variableStorage, yarnProgram)
    self.library = Library(true)
    self.program = yarnProgram
    self.variableStorage = variableStorage
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
end

function Dialogue:SetLineHandler(lineHandler)
    self.vm.lineHandler = lineHandler
end

function Dialogue:SetOptionsHandler(optionsHandler)
    self.vm.optionsHandler = optionsHandler
end

function Dialogue:SetCommandHandler(commandHandler)
    self.vm.commandHandler = commandHandler
end

function Dialogue:GetNodeVisitCount(nodeName)
    local variableName = GenerateUniqueVisitedVariableForNode(nodeName)
    local count = self.variableStorage:getVariable(variableName) or 0
    return count
end

function Dialogue:IsNodeVisited(nodeName)
    return self:GetNodeVisitCount(nodeName) > 0
end

function Dialogue:SetNode(nodeName)
    self.vm:SetNode(nodeName, true)
end

function Dialogue:SetSelectedOption(selectedOptionID)
    self.vm:SetSelectedOption(selectedOptionID);
end

function Dialogue:SetCoroutineRunning(coroutineRunning)
    self.coroutineRunning = coroutineRunning
end

function Dialogue:FinishCoroutine()
    self.coroutineRunning = nil
    self.vm:Continue()
end

function Dialogue:ProgressCoroutine()
    if self.coroutineRunning then
        self.coroutineRunning()
        return
    end
end

function Dialogue:Continue()
    if not self.vm.executionState == 'Running' or self.coroutineRunning then
        return
    end
    self.vm:Continue()
end

function Dialogue:Stop()
    self.vm:Stop()
end

function Dialogue:GetHeaderValue(nodeName, headerName)
    local node = self.program.nodes[nodeName]
    assert(node, "Node '" .. nodeName .. "' not found in program.")
    for key,value in pairs(node.headers) do
        if key == headerName then
            return playdate.string.trimWhitespace(value)
        end
    end
end

function Dialogue:GetSaliencyOptionsForNodeGroup(nodeGroupName)
    ---Not implemented yet
    assert(false, "GetSaliencyOptionsForNodeGroup is not implemented yet.")
    return {}
end

function AddCommandHandler(commandName, commandFunction)
    assert(self.library, "Library is not initialized.")
    self.library:registerCommand(commandName, commandFunction)
end
