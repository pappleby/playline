import "vm.lua"
import "utils.lua"

Playline = Playline or {}
local pu <const> = Playline.Utils
local pi <const> = Playline.Internal

local pushInstructionValueToStack = function(instruction, _, _, stack, _)
    table.insert(stack, instruction.value)
end
local instructionCases = {
    pushString = pushInstructionValueToStack,
    pushFloat = pushInstructionValueToStack,
    pushBool = pushInstructionValueToStack,
    pop = function(_, _, _, stack, _)
        table.remove(stack)
    end,
    callFunc = function(instruction, _, library, stack, _)
        pi.VM.SharedVMCallFunction(instruction.functionName, library, stack)
    end,
    pushVariable = function(instruction, variableAccess, _, stack, _)
        local variableName = instruction.variableName
        local loadedValue = variableAccess:Get(variableName)
        assert(loadedValue ~= nil, "Variable '" .. variableName .. "' has not been set and has no default value.")
        table.insert(stack, loadedValue)
    end,
    jumpIfFalse = function(instruction, _, _, stack, programCounter)
        local condition = stack[#stack]
        if not condition then
            programCounter[1] = instruction.targetNodeIndex
            return true
        end
    end,
    stop = function()
        return false
    end,
}
local evaluateInstruction = function(instruction, variableAccess, library, stack, programCounter)
    local opcode = instruction.instructionType.oneofKind
    local evalCase = instructionCases[opcode]
    assert(evalCase, "Unknown instruction type: " .. instruction.instructionType.oneofKind .. "in smartVariableVM")
    local evalResult = evalCase(instruction.instructionType[opcode], variableAccess, library, stack, programCounter)
    if evalResult ~= nil then
        return evalResult
    end
    programCounter[1] = programCounter[1] + 1
    -- Return true to indicate that we should continue
    return true
end

local getSmartVariable = function(name, variableAccess, program, library)
    assert(name ~= nil, "Smart variable name cannot be nil.")
    assert(variableAccess ~= nil, "Variable access cannot be nil.")
    assert(library ~= nil, "Library cannot be nil.")
    assert(program ~= nil, "Program cannot be nil.")

    local stack = {}
    local programCounter = { 1 }

    local smartVariableNode = program.nodes[name]
    assert(smartVariableNode, "Smart variable node '" .. name .. "' not found in program.")

    while programCounter[1] <= #smartVariableNode.instructions do
        local instruction = smartVariableNode.instructions[programCounter[1]]
        if not evaluateInstruction(instruction, variableAccess, library, stack, programCounter) then
            break
        end
    end

    assert(#stack == 1,
        "Error when evaluating smart variable " ..
        name .. " - stack did not end with a single remaining value after evaluation")

    local result = stack[1]
    return result
end

local getSaliencyOptionsForNodeGroup = function(nodeGroupName, variableAccess, program, library)
    local nodeGroup = program.nodes[nodeGroupName]
    assert(nodeGroup, "Node group '" .. nodeGroupName .. "' not found in program.")
    if pu.GetNodeHeaderValue(nodeGroup, "$Yarn.Internal.NodeGroupHub") == nil then
        -- This is not a node group, it's a plain node.
        -- Return a single content saliency "option" that represents this node.
        return { {
            complexityScore = 0,
            contentType = "node",
            passingConditionValueCount = 1,
            failingConditionValueCount = 0,
        } }
    end
    local options = {}
    for nodeName, node in pairs(program.nodes) do
        if pu.GetNodeHeaderValue(node, "$Yarn.Internal.NodeGroup") == nodeGroupName then
            local passingCount = 0
            local failingCount = 0
            local variables = pu.GetContentSaliencyConditionVariables(node)
            for _, variableName in ipairs(variables) do
                local variableValue = getSmartVariable(variableName, variableAccess, program, library)
                if variableValue == true then
                    passingCount = passingCount + 1
                elseif variableValue == false then
                    failingCount = failingCount + 1
                end
            end
            options[nodeName] = {
                complexityScore = pu.GetNodeHeaderValue(node, "$Yarn.Internal.ContentSaliencyComplexity") or -1,
                contentType = "node",
                passingConditionValueCount = passingCount,
                failingConditionValueCount = failingCount,
            }
        end
    end
    return options
end

Playline.SmartVariableVM = {
    GetSmartVariable = getSmartVariable,
    GetSaliencyOptionsForNodeGroup = getSaliencyOptionsForNodeGroup,
}
