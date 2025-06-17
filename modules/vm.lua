import "CoreLibs/object"

---@class VmState
class('VmState').extends()

function VmState:init()
    self.currentNodeName = nil
    self.programCounter = 1
    self.currentOptions = {}
    self.stack = {}
    self.callStack = {}
end

function VmState:PushValue(value)
    table.insert(self.stack, value)
end
function VmState:PopValue()
    return table.remove(self.stack)
end
function VmState:PopArgs(count)
    local args = {}
    for i = count, 1, -1 do
        args[i] = self:PopValue()
    end
    return args
end
function VmState:PeekValue()
    return self.stack[#self.stack]
end
function VmState:ClearStack()
    self.stack = {}
end
function VmState:PushCallStack()
    assert(self.currentNodeName,  "Cannot push call stack without a current node name")
    local valueToPush = {nodeName = self.currentNodeName, programCounter = self.programCounter}
    table.insert(self.callStack, valueToPush)
end
function VmState:CanReturn()
    return #self.callStack > 0
end
function VmState:PopCallStack()
    return table.remove(self.callStack)
end

---@class VM
class('VM').extends()
function VM:init(library, program, variableStorage)
    self.state = VmState()
    self.executionState = 'Stopped'
    self.contentSaliencyStrategy = nil -- Placeholder for default content saliency strategy
    self.saliencyCandidateList = {}
    self.variableStorage = variableStorage
    self.currentNode = nil
    self.nodeStartHandler = function () end
    self.prepareForLinesHandler =  function (lineIds) end
    self.optionsHandler = function (options) end
    self.dialogueCompleteHandler = function () end
    self.nodeCompleteHandler = function (nodeName) end
    self.lineHandler = function (line, substitutions) end
    self.commandHandler = function(commandText, library) end
    self.library = library
    self.program = program
end

function VM:ResetState()
    self.state = VmState()
end

function VM:SetExecutionState(newState)
    self.executionState = newState
    if(newState == 'Stopped') then
        self:ResetState()
    end
end
function VM:GetVariableDefaultValue(variableName)
    local variable = self.program.initialValues[variableName]
    if variable == nil or variable.value == nil or variable.value.oneofKind == nil then
        return nil
    end
    local variableKey = variable.value.oneofKind
    return variable.value[variableKey]
end
function VM:SetNode(nodeName, clearState)
    if(clearState == nil) then
        clearState = true
    end
    assert(self.program ~= nil or #self.program.nodes > 0, 'Cannot load node ' .. nodeName .. ' No nodes have been loaded.')
    if(self.program.nodes[nodeName] == nil) then
        self.executionState = 'Stopped'
        error('No node named ' .. nodeName .. ' has been loaded.')
    end
    print('Running node ' .. nodeName)

        if(clearState) then
            self:ResetState()
        end

    self.currentNode = self.program.nodes[nodeName]
    self.state.currentNodeName = nodeName
    self.state.programCounter = 1 -- lua index starts at 1 :/

    if self.nodeStartHandler then self.nodeStartHandler() end

    if self.prepareForLinesHandler and self.program.lineIdsForNode then
        local stringIds = self.program:lineIdsForNode(nodeName)
        self.prepareForLinesHandler(stringIds)
    end

    return true
end

function VM:Stop()
    self:SetExecutionState('Stopped')
    self.currentNode = nil
    if self.dialogueCompleteHandler then self.dialogueCompleteHandler() end
end

function VM:SetSelectedOption(option)
    assert(self.executionState == 'WaitingOnOptionSelection', "SetSelectedOption was called, but Dialogue wasn't waiting for a selection. This method should only be called after the Dialogue is waiting for the user to select an option.")
    assert(option ~= nil and option > 0 and option <= #self.state.currentOptions , option .. ' is not a valid option ID (expected a number between 1 and ' .. #self.state.currentOptions .. ')')

    -- We now know what number option was selected; push the
    -- corresponding node name to the stack
    local destination = self.state.currentOptions[option].destination
    self.state:PushValue(destination)

    -- We no longer need the accumulated list of options; clear it
    self.state.currentOptions = {}

    self.executionState = 'WaitingForContinue'
end

function VM:Continue()
    self:CheckCanContinue()

    if self.executionState == 'DeliveringContent' then
        -- We were delivering a line, option set, or command, and
        -- the client has called Continue() on us. We're still
        -- inside the stack frame of the client callback, so to
        -- avoid recursion, we'll note that our state has changed
        -- back to Running; when we've left the callback, we'll
        -- continue executing instructions.
        self.executionState = 'Running'
        return
    end

    self.executionState = 'Running'
    -- Execute instructions until something forces us to stop
    while self.currentNode ~= nil and self.executionState == 'Running' do
        local currentInstruction = self.currentNode.instructions[self.state.programCounter]
        self:RunInstruction(currentInstruction)
        self.state.programCounter += 1
        if self.currentNode ~= nil and self.state.programCounter > #self.currentNode.instructions then
          self:ReturnFromNode(self.currentNode)
          self.SetExecutionState('Stopped')
          if self.dialogueCompleteHandler then self.dialogueCompleteHandler() end
          print('Run complete.')
        end
    end
end

function VM:ReturnFromNode(node)
    if node == nil then return end -- Nothing to do
    
    if self.nodeCompleteHandler then self.nodeCompleteHandler(node.name) end
    local nodeTrackingVariable = node.trackingVariableName
    if nodeTrackingVariable then
        local oldValue = self.variableStorage[nodeTrackingVariable]
        
        if oldValue ~= nil then
            self.variableStorage[nodeTrackingVariable] = oldValue + 1
        else
            print('Failed to get the tracking variable for node '+ node.name)
        end
    end
end

function VM:CheckCanContinue()
   assert(self.currentNode ~= nil, "Cannot continue running dialogue. No node has been selected.")
   assert(self.executionState ~= 'WaitingOnOptionSelection', 'Cannot continue running dialogue. Still waiting on option selection.')
   assert(self.optionsHandler ~= nil, 'Cannot continue running dialogue. VM.optionsHandler has not been set.')
   assert(self.library ~= nil, 'Cannot continue running dialogue. VM.library has not been set.')
end

function VM:ExecuteJumpToNode(nodeName, isDetour)
    if isDetour then
        -- Preserve our current state.
        self.state:PushCallStack()
    else
        -- We are jumping straight to another node. Unwind the current
        -- call stack and issue a 'node complete' event for every node.
        self:ReturnFromNode(self.program.nodes[self.state.currentNodeName])
        while self.state:CanReturn() do
            local poppedNodeName = state:PopCallStack().nodeName
            if poppedNodeName ~= nil then 
                self:ReturnFromNode(self.program.nodes[poppedNodeName])
            end
        end
    end

    if nodeName == nil then nodeName = self.state:PeekValue() end

    self:SetNode(nodeName, not isDetour)

    -- Decrement program counter here, because it will
    -- be incremented when this function returns, and
    -- would mean skipping the first instruction
    self.state.programCounter -= 1
end

-- Shared between the normal vm and the smart variable vm
function SharedVMCallFunction(self, functionName)
    -- Call a function, whose parameters are expected to
    -- be on the stack. Pushes the function's return value,
    -- if it returns one. 
    local f = self.library:getFunction(functionName)
    local actualParamCount = self.state:PopValue() -- The first value on the stack is the number of parameters
    local params = {}
    for i = actualParamCount, 1, -1 do
        params[i] = self.state:PopValue()
    end
    local returnValue = f(table.unpack(params))
    if returnValue ~= nil then
        self.state:PushValue(returnValue)
    end
end

function VM:CallFunction(functionName)
    SharedVMCallFunction(self, functionName)
end
local vmRunInstructionCases = {
    jumpTo = function(self, instruction)
        self.state.programCounter = instruction.destination
    end,
    peekAndJump = function(self, _)
        self.state.programCounter = self.state:PeekValue() - 1 -- subtraction needed?
    end,
    runLine = function(self, instruction)
        -- Looks up a string from the string table and
        -- passes it to the client as a line
        local lineId = instruction.lineID
        local substitutionCount = instruction.substitutionCount or 0
        local substitutions = self.state:PopArgs(substitutionCount)
        self.executionState = 'DeliveringContent'
        self.lineHandler(lineId, substitutions)
        if self.executionState == 'DeliveringContent' then
            -- The client didn't call Continue, so we'll wait here.
            self.executionState = 'WaitingForContinue'
        end
    end,
    runCommand = function(self, instruction)
        local commandText = instruction.commandText
        local expressionCount = instruction.substitutionCount or 0
        for expressionIndex = expressionCount - 1, 0, -1 do
            local substitution = tostring(self.state:PopValue())
            local marker = "{" .. expressionIndex .. "}"
            commandText = string.gsub(commandText, marker, substitution)
        end
        print(commandText)
        self.executionState = 'DeliveringContent'
        self.commandHandler(commandText, self.library)
        if self.executionState == 'DeliveringContent' then
            -- The client didn't call Continue, so we'll wait here.
            self.executionState = 'WaitingForContinue'
        end
        
    end,
    addOption = function(self, instruction)
        local lineId = instruction.lineID
        local substitutionCount = instruction.substitutionCount or 0
        local destination = instruction.destination + 1
        local substitutions = self.state:PopArgs(substitutionCount)

        local resultOption = {
            id = instruction.id,
            lineId = lineId,
            substitutions = substitutions,
            destination = destination,
            enabled = true
        }
        if instruction.hasCondition then
            resultOption.enabled = self.state:PopValue()
        end

        table.insert(self.state.currentOptions, resultOption)
    end,
    showOptions = function(self, instruction)
        if #self.state.currentOptions == 0 then
            self:SetExecutionState('Stopped')
            self.dialogueCompleteHandler()
            return
        end
        self:SetExecutionState('WaitingOnOptionSelection')
        -- Wonder if we should yield here?
        -- This is where we pass the current options to the client
        self.optionsHandler(self.state.currentOptions)
        if self.executionState == 'WaitingForContinue' then
            -- we are no longer waiting on an option
            -- selection - the options handler must have
            -- called SetSelectedOption! Continue running
            -- immediately.
            self.executionState = 'WaitingForContinue'
        end
    end,
    pushString = function(self, instruction)
        self.state:PushValue(instruction.value)
    end,
    pushFloat = function(self, instruction)
        self.state:PushValue(instruction.value)
    end,
    pushBool = function(self, instruction)
        self.state:PushValue(instruction.value)
    end,
    jumpIfFalse = function(self, instruction)
        if self.state.PeekValue() == false then
            self.state.programCounter = instruction.destination
        end
    end,
    pop = function(self, instruction)
        self.state:PopValue()
    end,
    callFunc = function(self, instruction)
        self:CallFunction(instruction.functionName)
    end,
    pushVariable = function(self, instruction)
        local variableName = instruction.variableName
        local loadedValue = self.variableStorage[variableName]
        if loadedValue == nil then
            loadedValue = self:GetVariableDefaultValue(variableName)
        end
        assert(loadedValue ~= nil, "Variable '" .. variableName .. "' has not been set and has no default value.")
        self.state:PushValue(loadedValue)
    end,
    storeVariable = function(self, instruction)
        local loadedValue = self.state:PopValue()
        local variableName = instruction.variableName
        self.variableStorage[variableName] = loadedValue
    end,
    stop = function(self, instruction)
        self:ReturnFromNode(self.currentNode)
        while self.state:CanReturn() do
            local poppedNodeName = state:PopCallStack().nodeName
            if poppedNodeName ~= nil then
                self:ReturnFromNode(self.program.nodes[poppedNodeName])
            end
        end
        self:dialogueCompleteHandler()
        self:SetExecutionState('Stopped')
    end,
    runNode = function(self, instruction)
        self:ExecuteJumpToNode(instruction.nodeName, false)
    end,
    peekAndRunNode = function(self, _)
        self:ExecuteJumpToNode(nil, false)
    end,
    detourToNode = function(self, instruction)
        self:ExecuteJumpToNode(instruction.nodeName, true)
    end,
    peekAndDetourToNode = function(self, _)
        self:ExecuteJumpToNode(nil, true)
    end,
    ["return"] = function(self, _)
        self:ReturnFromNode(self.currentNode)
        local returnSite = {}
        if self.state:CanReturn() then
            returnSite = self.state:PopCallStack()
        end
        if returnSite.nodeName ~= nil then
            self:SetNode(returnSite.nodeName, false)
            self.state.programCounter = returnSite.programCounter
        else
            -- No more nodes to return to, stop execution
            self:Stop()
        end
    end,
    addSaliencyCandidate = function(self, instruction)
        local condition = self.state:PopValue()
        local candidate = {
            contentId = instruction.contentId,
            complexityScore = instruction.complexityScore,
            failingConditionValueCount = condition and 0 or 1,
            passingConditionValueCount = condition and 1 or 0,
            destination = instruction.destination + 1,
            contentType = "line"
        }
        table.insert(self.saliencyCandidateList, candidate)
    end,
    addSaliencyCandidateFromNode = function(self, instruction)
        local nodeName = instruction.nodeName
        local passed = 0
        local failed = 0
        local node = self.program.nodes[nodeName]
        if node == nil then
            error("Node '" .. nodeName .. "' does not exist in the program.")
        end
        for variableName in node.contentSaliencyConditionVariables do
            local result = self.variableStorage.smartVariableEvaluator:evaluate(variableName)
            if result then
                passed += 1
            else
                failed += 1
            end
        end
        local complexityScore = node.complexityScore or 0
        local candidate = {
            contentId = nodeName,
            complexityScore = complexityScore,
            failingConditionValueCount = failed,
            passingConditionValueCount = passed,
            destination = node.destination + 1,
            contentType = "node"
        }
        table.insert(self.saliencyCandidateList, candidate)
    end,
    selectSaliencyCandidate = function(self, _)
        local result = self.contentSaliencyStrategy:queryBestContent(self.saliencyCandidateList)
        if result ~= nil then
            -- TODO Validate that the result was in the candidate list
            self.contentSaliencyStrategy:contentWasSelected(result)
            self.state:pushValue(result.destination)
            self.state:pushValue(true)
        else
            -- Push a flag indicating that content was not selected.
            self.state:pushValue(false)
        end 
        self.saliencyCandidateList = {} -- Clear the candidate list after selection
    end,
}
function VM:RunInstruction(instruction)
    local opcode = instruction.instructionType.oneofKind
    local handler = vmRunInstructionCases[opcode]
    assert(handler, "No handler for instruction opcode: " .. instruction.instructionType.oneofKind)
    handler(self, instruction.instructionType[opcode])
end