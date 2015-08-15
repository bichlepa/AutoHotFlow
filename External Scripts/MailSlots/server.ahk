;Mailslot Server (server is actually the RECIPIENT of mail messages; client sends them)

;MSDN says Windows functions used all Windows 2K or higher (DLLs in kernel32)
;Tested only under XP Pro with SP3

;This script has no hotkeys or user interface, so it must be closed using Exit in
;menu from right click of its notification area icon
;A proper implementation should use CloseHandle before exiting or when done with the mailslot

/*
USEFUL LINKS:
http://msdn.microsoft.com/en-us/library/aa365147(v=VS.85).aspx	CreateMailslot Function
http://msdn.microsoft.com/en-us/library/aa365467(v=VS.85).aspx	ReadFile Function
http://msdn.microsoft.com/en-us/library/ms681381(v=VS.85).aspx	System Error Codes
http://msdn.microsoft.com/en-us/library/aa365785(v=VS.85).aspx	Using mailslots (example in C/C++)
*/


;"adding the line #NoEnv anywhere in the script improves DllCall's
; performance when unquoted parameter types are used (e.g. int vs. "int")."

;mailslot name MUST begin with "\\.\mailslot\", since it is created on local machine
;Name can include "pseudopath" e.g. \\.\mailslot\MainPostOffice\FredsBoxes\Box123

;Note: This file is not original. It has been modified for AutoHotFlow.

MailSlotCreateSlot(Name)
{
	global
	SlotName = \\.\mailslot\%Name%
	MsgBox %SlotName%
	;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~CREATE MAILSLOT
	SlotHandle := DLLCall("CreateMailslot"  ;return is handle (integer) to the mailslot
		,str, SlotName	
		,UInt, 0	;using zero allows max message size
		,UInt, 0	;0 return immediately if no message; otherwise ms to wait, -1 for wait forever
		,UInt, 0)	;security attributes

	if errorlevel ;this is an error reported by AHK in attempting the call
	{
		MsgBox An error occured in the AHK call to CreatMailslot.`nExiting.
		exitapp
	}
	else if (a_lasterror <> 0) ;error reported by the CreateMailslot function itself (not AHK)
	{
		clipboard = http://msdn.microsoft.com/en-us/library/ms681381(v=VS.85).aspx	
		MsgBox CreateMailSlot function returned an error.`nSystem Error Code: %a_lasterror%`n`nLink to error codes is on clipboard.
		
	}
	MsgBox %SlotHandle%
	return SlotHandle
}
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;Mailslot is now ready to receive incoming mail from client application
;Reading from the mailslot is done using Windows ReadFile function

;Note that the mailslot was created with zero for wait time, so an attempted read will return immediately
;even if the mailslot is empty.
;Windows function GetMailslotInfo can be use to check, in advance of reading, how many messages are in
;the slot and how large the next message is

;MSDN doc's are inconsistent with regard to size limit for messages sent between computers on a network.
;One place says 400 for broadcast, another says 424 for messages between computers.
;This server and companion client will work for up to 420 under Windows XP.
;Messages sent from one process to another on the same computer can be much longer, with the limit set
;Max Msg Size at slot creation

;Define the maximum string length here:
MailslotMaxStringLength:=1000000

VarSetCapacity(MailSlotReadBuffer, MailslotMaxStringLength*2+2, 0)



MailslotRead(SlotHandle) ;reads one message at a time
{
	global MailSlotReadBuffer  ;could/should be passed as ByRef parameter
	global BytesActuallyRead  ;could/should be passed as ByRef parameter
	global maxstringlength  

	BytesToRead := MailslotMaxStringLength*2+2
	
	DLLCall("ReadFile"
		,UInt, slotHandle	;the handle from CreateMailSlot
		,str , MailSlotReadBuffer	;see AHK DLLCall Help for why str used here
		,UInt, BytesToRead	
		,UIntP, BytesActuallyRead
		,UInt, 0)	;pointer to Overlapped structure, not used, so null
	
	if errorlevel
		Msgbox Error in ReadFile operation`nErrorLevel: %errorlevel%
	else
		return BytesActuallyRead
}