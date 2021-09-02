;The hidden window can receive messages from other processes.
;The initial purpose is to allow the trigger "shortcut". This trigger creates a shortcut.
;The shortcut starts the AutoHotFlow.ahk/exe and it sends the message to start the trigger to the already running AHF instance.

; create a hidden window which will be able to receive commands from outside
CreateHiddenCommandWindow()
{
	global
	gui, HiddenCommandWindow:add, edit, gHiddenCommandWindowOnNewMessage vHiddenCommandWindowEditMessage
	gui, HiddenCommandWindow:show, hide, %_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW
}

; a new command was pasted in the hidden window.
HiddenCommandWindowOnNewMessage()
{
	global HiddenCommandWindowEditMessage

	; get the command
	guicontrolget, newMessage,, HiddenCommandWindowEditMessage

	; process the command
	HiddenCommandWindowProcessMessage(newMessage)
}

; Process a command which was passed to the hidden window
HiddenCommandWindowProcessMessage(message)
{
	; split the parts of the message, which are delimited by pipes
	messageParsed := Object()
	loop, parse, message, |
	{
		messageParsed.push(A_LoopField)
	}

	; process known commands
	if (messageParsed[1] = "trigger")
	{
		flowID := messageParsed[2]
		triggerID := messageParsed[3]
		
		if (_getElementInfo(flowID, triggerID, "enabled"))
		{
			API_Execution_ExecuteFlow(flowID, triggerID)
		}
	}
	Else
	{
		logger("a0", "unknown command received through command window: " substr(messageParsed, 1, 100))
	}
}