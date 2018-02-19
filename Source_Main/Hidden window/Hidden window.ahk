;The hidden window can receive messages from other processes.
;The initial purpose is to allow the trigger "shortcut". This trigger creates a shortcut.
;The shortcut starts the AutoHotFlow.ahk/exe and it sends the message to start the trigger to the already running AHF instance.


CreateHiddenCommandWindow()
{
	global
	gui,HiddenCommandWindow:add, edit, gHiddenCommandWindowNewMessage vHiddenCommandWindowEditMessage
	gui,HiddenCommandWindow:show,hide,%_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW
}

HiddenCommandWindowNewMessage()
{
	global HiddenCommandWindowEditMessage
	guicontrolget,newMessage,,HiddenCommandWindowEditMessage
	
	messageParsed:=Object()
	loop,parse,newMessage,|
	{
		messageParsed.push(A_LoopField)
	}
	if (messageParsed[1] = "trigger")
	{
		API_Execution_startFlow(messageParsed[2], messageParsed[3])
		
	}
}