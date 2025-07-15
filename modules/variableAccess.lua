import 'CoreLibs/object'
import 'smartVariableVM.lua'

Playline = Playline or {}

Playline.VariableAccess = {}

class('VariableAccess', nil, Playline).extends()
function Playline.VariableAccess:init(variableStorage, program, library)
    self.variableStorage = variableStorage or {}
    self.program = program or {}
    self.library = library
    self.smartVariableNames = {}
    for nodeName, nodeValue in pairs(self.program.nodes) do
        for _, header in ipairs(nodeValue.headers) do
            if header.key == "tags" and header.value == "Yarn.SmartVariable" then
                self.smartVariableNames[nodeName] = true
            end
        end
    end
end

function Playline.VariableAccess:GetDefaultValue(name)
    local variable = self.program.initialValues[name]
    if variable == nil or variable.value == nil or variable.value.oneofKind == nil then
        return nil
    end
    local variableKey = variable.value.oneofKind
    return variable.value[variableKey]
end

function Playline.VariableAccess:GetSmartVariableValue(name)
    if self.smartVariableNames[name] then
        return Playline.SmartVariableVM.GetSmartVariable(name, self, self.program, self.library)
    end
    return nil
end

function Playline.VariableAccess:Get(name)
    local value = self.variableStorage[name]

    if value == nil then
        value = self:GetSmartVariableValue(name)
    end

    if value == nil then
        value = self:GetDefaultValue(name)
    end
    return value
end

function Playline.VariableAccess:Set(name, value)
    self.variableStorage[name] = value
end
