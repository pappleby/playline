import 'CoreLibs/object'

Playline = Playline or {}

Playline.DialoguePresenterBase = {}
class('DialoguePresenterBase', nil, Playline).extends()

function Playline.DialoguePresenterBase:init()
end

function Playline.DialoguePresenterBase:RunLine(lineInfo)
   -- This method can be overridden by subclasses to handle lines
end

function Playline.DialoguePresenterBase:RunOptions(options)
   -- This method can be overridden by subclasses to handle options
end

function Playline.DialoguePresenterBase:RunCommand(commandName, args)
   -- This method can be overridden by subclasses to handle commands
end

function Playline.DialoguePresenterBase:OnDialogueStarted()
   -- This method can be overridden by subclasses to handle dialogue 
   -- TODO: Add handling on the dialogue side to call this and make it coroutine friendly
end

function Playline.DialoguePresenterBase:OnDialogueComplete()
    -- Called by the <see cref="DialogueRunner"/> to signal that the
    --- dialogue has ended, and no more lines will be delivered.
    --- TODO: Add handling on the dialogue side to call this and make it coroutine friendly
end