#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1
#SingleInstance off
CoordMode,mouse,client
;FileEncoding,UTF-8
OnExit,Exit


hModule := DllCall("LoadLibrary","Str",a_scriptdir "\AutoHotKey\AutoHotkey_H.exe")

DetectHiddenWindows,on
preventSecondPromptToSave:=false

FlowLastActivity:=a_now

if not a_iscompiled
	developing=yes

DebugLogLevelApp=3 ;Debug level for app debugs: 0=Only errors; 1=Important logs; 2=Detailed logs ; 3=Debug logs
DebugLogLevelFlow=3 ;Debug levels: 0=Only errors; 1=Important logs; 2=Detailed logs ; 3=Debug logs

share:=CriticalObject()
share.flowSettings:=[]
share.flow:=[]
share.flowSettings.ExecutionPolicy:="parallel"
share.flowSettings.MaximumCountOfParallelInstances:=100
share.flowSettings.MaximumCountOfExeThreads:=1
share.flow.ClipboardFilePath:=A_ScriptDir "\Clipboard.ini"
;~ LangNoUseCache:=true ;only for debugging

;Priorities
c_PriorityForIteration:=-50
c_PriorityForInstanceInitialization:=-100

NoTests:=true ;prevent some test routines. Should be activated.

lang_FindAllLanguages()
ini_ReadSettings()
;~ MsgBox §%CurrentManagerHiddenWindowID%§
If not winexist(CommandWindowOfManager , "§" CurrentManagerHiddenWindowID "§")
{

	logger("a2","Manager is not running. Closing flow.")
		MsgBox, 48, AutoHotFlow, % lang("The AutoHotFlow manager needs to be started first, before a flow can be opened.") "`n" lang("The flow will close now."),5
	exitapp
}

;Fill cache, so that the ini files from translations will not be read every time a translation is needed --> more speed



iniAllActions=
iniAllConditions=
iniAllTriggers=

#Include %A_ScriptDir% 


;If you add an element, include the ahk
;the inclusion order affects the appearance order in the element selection GUI
#include elements\actions\New_Variable.ahk ;First element in Category variables
;~ #include elements\actions\tooltip.ahk ;First element in Category user interaction
;~ #include elements\actions\Sleep.ahk ;First element in Category Flow control
;~ #include elements\actions\Send_Keystrokes.ahk ;first element in category user simulation
;~ #include elements\actions\Activate_Window.ahk ;First element in category window
;~ #include elements\actions\run.ahk ;First element in category process
;~ #include elements\actions\Write_to_file.ahk ;first element in category files
;~ #include elements\actions\Eject_Drive.ahk ;first element in category drive
;~ #include elements\actions\Search_image.ahk ;first element in category image
;~ #include elements\actions\Play_Sound.ahk ;first element in category sounds
;~ #include elements\actions\Download_file.ahk ;first element in category internet
;~ #include elements\actions\lock_computer.ahk ;first element in category power
;~ #include elements\actions\AutoHotKey_script.ahk ;first element in category for experts
;~ ;actions in category variable
;~ #include elements\actions\Copy_variable.ahk
;~ #include elements\actions\Get_Clipboard.ahk
;~ #include elements\actions\Set_Clipboard.ahk
;~ #include elements\actions\Absolute_number.ahk
;~ #include elements\actions\Rounding_a_number.ahk
;~ #include elements\actions\Random_number.ahk
;~ #include elements\actions\Exponentiation.ahk
;~ #include elements\actions\Square_Root.ahk
;~ #include elements\actions\Trigonometry.ahk
;~ #include elements\actions\Substring.ahk
;~ #include elements\actions\Trim_a_string.ahk
;~ #include elements\actions\Replace_a_string.ahk
;~ #include elements\actions\Search_in_a_string.ahk
;~ #include elements\actions\Split_a_string.ahk
;~ #include elements\actions\Get_string_length.ahk
;~ #include elements\actions\Change_character_case.ahk
;~ #include elements\actions\New_date.ahk
;~ #include elements\actions\Date_Calculation.ahk
;~ #include elements\actions\New_list.ahk
;~ #include elements\actions\Add_to_list.ahk
;~ #include elements\actions\Get_from_list.ahk
;~ #include elements\actions\Delete_from_list.ahk
;~ #include elements\actions\Get_index_of_element_in_list.ahk
;~ #include elements\actions\Shuffle_list.ahk

;~ ;actions in category user interaction
#include elements\actions\Traytip.ahk
;~ #include elements\actions\Message_Box.ahk
;~ #include elements\actions\Input_box.ahk
;~ #include elements\actions\Speech_output.ahk ;user interaction and sound

;~ ;actions in category flow control
;~ #include elements\actions\Set_flow_status.ahk
;~ #include elements\actions\Execute_flow.ahk
;~ #include elements\actions\Stop_flow.ahk

;~ ;actions in category window
;~ #include elements\actions\Close_Window.ahk
;~ #include elements\actions\Kill_Window.ahk
;~ #include elements\actions\Move_window.ahk
;~ #include elements\actions\Show_window.ahk
;~ #include elements\actions\Hide_window.ahk
;~ #include elements\actions\Minimize_all_windows.ahk
;~ #include elements\actions\Send_Keystrokes_to_Control.ahk ;Window and user simulation
;~ #include elements\actions\Get_control_text.ahk
;~ #include elements\actions\Set_control_text.ahk

;~ ;actions in category user simulation
;~ #include elements\actions\Click.ahk
;~ #include elements\actions\Move_mouse.ahk
;~ #include elements\actions\Drag_with_mouse.ahk
;~ #include elements\actions\Get_mouse_position.ahk
;~ #include elements\actions\Set_lock_key.ahk

;~ ;actions in category process
;~ #include elements\actions\Kill_Process.ahk
;~ #include elements\actions\Set_process_priority.ahk

;~ ;actions in category files
;~ #include elements\actions\Delete_file.ahk
;~ #include elements\actions\Copy_file.ahk
;~ #include elements\actions\Move_file.ahk
;~ #include elements\actions\Rename_file.ahk
;~ #include elements\actions\Read_from_file.ahk
;~ #include elements\actions\Recycle_file.ahk
;~ #include elements\actions\Create_folder.ahk
;~ #include elements\actions\Copy_folder.ahk
;~ #include elements\actions\Move_folder.ahk
;~ #include elements\actions\Rename_folder.ahk
;~ #include elements\actions\Delete_folder.ahk
;~ #include elements\actions\Write_to_ini.ahk
;~ #include elements\actions\Read_from_ini.ahk
;~ #include elements\actions\Delete_from_ini.ahk
;~ #include elements\actions\Get_file_size.ahk
;~ #include elements\actions\Get_file_time.ahk
;~ #include elements\actions\Set_file_time.ahk
;~ #include elements\actions\Get_file_attributes.ahk
;~ #include elements\actions\Set_file_attributes.ahk
;~ #include elements\actions\Select_file.ahk ;files and user interaction
;~ #include elements\actions\Select_folder.ahk ;files and user interaction
;~ #include elements\actions\Empty_recycle_bin.ahk

;~ ;actions in category drive
;~ #include elements\actions\Lock_Or_Unlock_Drive.ahk
;~ #include elements\actions\Get_Drive_Information.ahk
;~ #include elements\actions\Change_Drive_Label.ahk
;~ #include elements\actions\List_Drives.ahk 

;~ ;actions in category sound
;~ #include elements\actions\Stop_Sound.ahk
;~ #include elements\actions\Beep.ahk
;~ #include elements\actions\Set_Volume.ahk
;~ #include elements\actions\Get_Volume.ahk

;~ ;actions in category image
;~ #include elements\actions\Search_pixel.ahk
;~ #include elements\actions\Get_pixel_color.ahk
;~ #include elements\actions\Screenshot.ahk
;~ #include elements\actions\Get_Monitor_Settings.ahk
;~ #include elements\actions\Set_Monitor_Settings.ahk

;~ ;actions in category internet
;~ #include elements\actions\HTTP_Request.ahk

;~ ;actions in category power
;~ #include elements\actions\log_off.ahk
;~ #include elements\actions\Shutdown.ahk
;~ #include elements\actions\reboot_computer.ahk
;~ #include elements\actions\hibernate_computer.ahk
;~ #include elements\actions\suspend_computer.ahk

;actions in category for experts



;~ #include elements\conditions\expression.ahk
;~ #include elements\conditions\Variable_is_empty.ahk
;~ #include elements\conditions\String_contains_text.ahk
;~ #include elements\conditions\List_contains_element.ahk
;~ #include elements\conditions\confirmation_dialog.ahk
;~ #include elements\conditions\key_is_down.ahk
;~ #include elements\conditions\flow_enabled.ahk
;~ #include elements\conditions\flow_running.ahk
;~ #include elements\conditions\window_active.ahk
;~ #include elements\conditions\window_Exists.ahk
;~ #include elements\conditions\Process_is_running.ahk
;~ #include elements\conditions\File_exists.ahk
;~ #include elements\conditions\File_has_attribute.ahk
;~ #include elements\conditions\debug_dialog.ahk

;~ #include elements\triggers\window_opens.ahk
;~ #include elements\triggers\window_Closes.ahk
;~ #include elements\triggers\Window_Gets_Active.ahk
;~ #include elements\triggers\Window_Gets_Inactive.ahk
;~ #include elements\triggers\Hotkey.ahk
;~ #include elements\triggers\Shortcut.ahk
;~ #include elements\triggers\Periodic_timer.ahk
;~ #include elements\triggers\Clipboard_Changes.ahk
;~ #include elements\triggers\start_up.ahk
;~ #include elements\triggers\Time_of_day.ahk
;~ #include elements\triggers\User_Idle_Time.ahk
;~ #include elements\triggers\Process_starts.ahk
;~ #include elements\triggers\Process_closes.ahk
;~ #include elements\triggers\File_Observer.ahk


;~ #include elements\loops\SimpleLoop.ahk
;~ #include elements\loops\Condition.ahk
;~ #include elements\loops\Work_through_a_list.ahk
;~ #include elements\loops\Loop_through_files.ahk
;~ #include elements\loops\Parse_a_string.ahk

*/

;include other stuff
#include language\language.ahk ;Must be very first
#include editor\ini\Ini_compability.ahk ; must be first
#include editor\ini\Ini_Settings.ahk ; must be first
#include editor\ini\Ini_save.ahk
#include editor\ini\Ini_savetoclipboard.ahk
#include editor\ini\Ini_loadfromclipboard.ahk
#include editor\ini\Ini_load.ahk
#include editor\Elements\e_elements.ahk
;#include editor\Elements\e_ErrorCorrection.ahk
;#include elements\script generation.ahk
#include elements\functions for elements.ahk
;#include elements\Get window information.ahk
;#include elements\Get control information.ahk
;#include elements\Choose color.ahk
;#include elements\Mouse tracker.ahk
#include editor\Variables\v_Variables.ahk
#include editor\Variables\v_Expression.ahk
#include editor\User Interface\ui_GDI+.ahk
#include editor\User Interface\ui_GDI+Thread.ahk
#include editor\User Interface\ui_Mouse.ahk
#include editor\User Interface\ui_Help.ahk
#include editor\User Interface\ui_Element_Settings.ahk
#include editor\User Interface\ui_Menu_Bar.ahk
#include editor\User Interface\ui_Main_GUI.ahk
#include editor\User Interface\ui_tooltip.ahk
#include editor\User Interface\ui_flow_settings.ahk
#include editor\User Interface\ui_Tray.ahk
#include editor\Communication\Receive.ahk
#include editor\Communication\Send.ahk
#include editor\Undo\undo - redo.ahk

#include editor\run\r_run.ahk
#include editor\run\r_Instance.ahk
#include editor\run\r_ExecutionThread.ahk
;#include editor\run\r_enable.ahk
#include editor\Debug\d_Debug.ahk
#include editor\Debug\d_Logger.ahk



#include External Scripts\gdi+\gdip.ahk
#include External Scripts\TTS\TTS by Learning One.ahk
#include External Scripts\HTTP Request\HTTPRequest.ahk
#include External Scripts\HTTP Request\URIEncode.ahk
#include External Scripts\Eject by skan\Eject by skan.ahk
#include External Scripts\ScrollGui\Class_ScrollGUI.ahk
#include External Scripts\Object to file\String-object-file.ahk
#include External Scripts\SizeOf and Struct\_struct.ahk
#include External Scripts\SizeOf and Struct\sizeof.ahk
#include External Scripts\WatchDirectory\Watch direcotry.ahk
#include External Scripts\Class_Monitor\Class_Monitor.ahk
;~ #include External Scripts\Class_Monitor\Device gamma ramp.ahk
#include External Scripts\CPU load\CPU load.ahk
#include External Scripts\OS install date\OS install date.ahk
#include External Scripts\Memory load\Memory load.ahk
#include External Scripts\Robert - Ini library\Robert - Ini library.ahk

#include External Scripts\different external functions.ahk

;Not in use yet. maybe later
;~ #include External Scripts\MailSlots\Server.ahk
;~ #include External Scripts\MailSlots\Client.ahk
;#include External Scripts\fincs-ahk-eval\Lib\eval.ahk
;#include External Scripts\Uberi - ExprEval\Dynamic Expressions.ahk


;Trim the last "|" character, because it is not needed
StringTrimRight,iniAllActions,iniAllActions,1
StringTrimRight,iniAllConditions,iniAllConditions,1
StringTrimRight,iniAllTriggers,iniAllTriggers,1




ini_GetElementInformations()

;close if the manager closes
;SetTimer,endWhenManagerCloses,500



OnExit, ExitAppOverride

;Initialize some variables
clickModus=normal ;click clickModus

triggersenabled:=false



ReceivedCommandsBuffer=
CommandCount=0

;Developping:
;~ if developing=yes
;~ {

;~ run,Manager\DevelopmentHelper.ahk
;~ }

;SetTimer,CheckWhetherInactive,10000

;Add the Trigger element
maintrigger:=element_new("trigger","trigger")
;Create the saving folder for generated scripts
FileCreateDir Generated Scripts

;Create a hidden window to allow other triggers or manager to send messages 
;~ com_CreateHiddenReceiverWindow()


maingui:=new maingui() ;Create the main GUI

;Create thread for drawing
ui_initGDIThread()

r_StartExecutionThreads()

;Evaluate parameters
if 1=EditFlow 
{
	OnStartLoadFile=%2%
	logger("a1","Editor Started. The flow """ OnStartLoadFile """ should be edited because of parameter.")
	
	;It may happen that the editor for that flow is already opened. Try to send the command to the command window of the editor to start the flow, if it is already open. If not load flow and start it.
	Iniread,FlowName,%OnStartLoadFile%,general,name 
	if checkWhetherThisFlowIsAlreadyOpen(FlowName)
	{
		ExitApp
	}
	
	i_load(OnStartLoadFile)
	maingui.show()
}
else if 1=RunFlow 
{
	; %1%: runflow
	; %2%: filepath of save file
	; %3%: ID of trigger
	OnStartLoadFile=%2%
	OnStartTriggerID=%3%
	logger("a1","Editor Started. The flow """ OnStartLoadFile """ should be run because of parameter.")
	
	;It may happen that the editor for that flow is already opened. Try to send the command to the command window of the editor to start the flow, if it is already open. If not load flow and start it.
	Iniread,FlowName,%OnStartLoadFile%,general,name 
	if checkWhetherThisFlowIsAlreadyOpen(FlowName)
	{
		com_SendCommand({function: "ChangeFlowStatus", status: "run", flowName: FlowName,CallerElementID: "Parameter"},"manager") ;Send the command to the Manager.
		ExitApp
	}
	
	i_load(OnStartLoadFile)
	
	;r_Trigger(OnStartTriggerID) ;todo
	return
}
else if 1=EnableFlow 
{
	EnableFlowOptions=%3%
	
	OnStartLoadFile=%2%
	logger("a1","Editor Started. The flow """ OnStartLoadFile """ should be enabled because of parameter.")
	
	;It may happen that the editor for that flow is already opened. Try to send the command to the command window of the editor to start the flow, if it is already open. If not load flow and start it.
	Iniread,FlowName,%OnStartLoadFile%,general,name 
	if checkWhetherThisFlowIsAlreadyOpen(FlowName)
	{
		com_SendCommand({function: "ChangeFlowStatus", status: "enable", flowName: FlowName,CallerElementID: "Parameter"},"manager") ;Send the command to the Manager.
		ExitApp
	}
	
	i_load(OnStartLoadFile)
	;goto,ui_Menu_Enable ;TODO
	return
}
else if INIOnStartLoadFile<> ;If a flow should be opened at startup
{
	maingui.show()
	logger("a1","Editor Started. The flow """ INIOnStartLoadFile """ should be edited because of ini file.")
	
	;It may happen that the editor for that flow is already opened. Try to send the command to the command window of the editor to start the flow, if it is already open. If not load flow and start it.
	Iniread,FlowName,%OnStartLoadFile%,general,name 
	if checkWhetherThisFlowIsAlreadyOpen(FlowName)
	{
		ExitApp
	}
	
	i_load(INIOnStartLoadFile)
	IniDelete,settings.ini,common,LoadFileOnStart
	
}
else
{

	logger("a0","Editor Started, but no flow to start available.")
	MsgBox, 64, AutoHotFlow editor, This editor is only designed to be opened by the AutoHotFlow Manager. Please open the manager if you want to edit a flow.
		ExitApp
	
	;~ maingui.show() ;Show an empty flow
	
}


return

checkWhetherThisFlowIsAlreadyOpen(FlowName)
{
	
	loop 3
	{
		com_SendCommand({function: "nothing"},"editor",FlowName) ;Send the command to the Editor.
		if not errorlevel
		{
			
			return true
		}
		sleep 20
	}
	return false
}






CheckWhetherInactive:
tempFlowLastActivityDifference:=FlowLastActivity
EnvSub,tempFlowLastActivityDifference,a_now,seconds

DetectHiddenWindows off
IfWinExist,ahk_id %MainGuihwnd%
{
	FlowLastActivity:=a_now
}
else if (triggersEnabled=true)
{
	FlowLastActivity:=a_now
}
else if (nowRunning=true)
{
	FlowLastActivity:=a_now
}
else if (not i_CheckIfSaved())
{
	FlowLastActivity:=a_now
}
else if (tempFlowLastActivityDifference> 60 * 10) ;After 10 minutes inactivity, close editor
{
	ExitApp
}
return




endWhenManagerCloses:
if nowexiting
	return

IfWinnotExist,ahk_id %CurrentManagerHiddenWindowID%
{
	loop 5
	{
		iniread,CurrentManagerHiddenWindowID,settings.ini,common,Hidden window ID of manager
		IfWinExist,ahk_id %CurrentManagerHiddenWindowID%
		{
			;r_TellCurrentStatus() ;TODO
			sleep 500
			;r_TellCurrentStatus() ;TODO
			return
		}
		sleep 100
		
	}
	
	logger("a2","Manager was closed. Closing flow.")
	exitapp
}
return

*/
return
mainguiguiclose:
logger("a3","GUI closed by user.")
gui,maingui:hide
;~ ToolTip saved %saved% nowexiting %nowexiting%
if ((not i_CheckIfSaved()) and  nowexiting!=true)
{
	;~ MsgBox, 65, AutoHotFlow, % lang("Note!") " " lang("You have not saved.") "`n" lang("Click on OK to save now."), 5
	
	gui,ExitMessageBox:Destroy
	gui,ExitMessageBox:add,text,x10 y10 w230 h100,% lang("Note!") " " lang("You have not saved.") "`n" lang("Do_you_want_to_save?")
	gui,ExitMessageBox:add,button,Y+10 xp w100 h30 gExitMessageBoxSave default,% lang("Save")
	gui,ExitMessageBox:add,button,X+10 yp w100 h30 gExitMessageBoxCancel,% lang("Later")
	gui,ExitMessageBox:-sysmenu
	gui,ExitMessageBox:show
	gui,ExitMessageBox:+hwndExitMessageBoxHWND
	settimer,ExitMessageBoxTimeout,-5000
	return
	
}



return



Exit:
if (nowexiting=true)
{
	WinActivate,ahk_id %ExitMessageBoxHWND%
}
ExitApp
return

ExitAppOverride:
nowexiting:=true

if ((not i_CheckIfSaved()) and immediatelyexit!="true" and (not preventSecondPromptToSave))
{
	;ui_showgui()
	logger("a3","Asking user to save flow")
	gui,ExitMessageBox:Destroy
	gui,ExitMessageBox:add,text,x10 y10 w330 h60,% lang("You_have_not_saved.") "`n`n" lang("Do_you_want_to_save?")
	gui,ExitMessageBox:add,button,Y+10 xp w100 h30 gExitMessageBoxSaveAndClose default,% lang("Save")
	gui,ExitMessageBox:add,button,X+10 yp w100 h30 gExitMessageBoxClose,% lang("Don't save")
	gui,ExitMessageBox:add,button,X+10 yp w100 h30 gExitMessageBoxCancel,% lang("Cancel")
	;~ MsgBox,3,% lang("Exit"),% lang("You_have_not_saved.") "`n`n" lang("Do_you_want_to_save?")
	gui,ExitMessageBox:-sysmenu
	gui,ExitMessageBox:show
	gui,ExitMessageBox:+hwndExitMessageBoxHWND
	
	settimer,ExitMessageBoxTimeout,off
	return
	
	
}
else if (immediatelyexit!="true")
{
	i_saveGeneralParameters()
}

preventSecondPromptToSave=1 ;Prevent second prompt to save

if (triggersEnabled=true)
{
	logger("a2","Flow is currently enabled. Disabling flow")
	;~ FileAppend,%A_ExitReason%`n,test.txt
	;if (A_ExitReason ="shutdown" or A_ExitReason = "logoff")
		;r_EnableFlow("noTellDisabled")
	;else
		;r_EnableFlow()

}
if nowRunning=true
{
	logger("a2","Flow is currently running. Stopping flow")
	stopRun=true
	settimer,exit,-500
	return
}
;r_TellThatFlowIsStopped()
; gdi+ may now be shutdown on exiting the program
Gdip_Shutdown(pToken)
logger("a1","Exit")
exitapp
Return


ExitMessageBoxSave:
logger("a3","User wants to save")
settimer,ExitMessageBoxTimeout,off
gui,ExitMessageBox:Destroy
i_save()
return
ExitMessageBoxSaveAndClose:
logger("a3","User wants to save")
settimer,ExitMessageBoxTimeout,off
gui,ExitMessageBox:Destroy
i_save()
immediatelyexit=true
ExitApp
return
ExitMessageBoxClose:
logger("a3","User does not want to save")
settimer,ExitMessageBoxTimeout,off
gui,ExitMessageBox:Destroy
immediatelyexit=true
ExitApp
return
ExitMessageBoxCancel:
settimer,ExitMessageBoxTimeout,off
gui,ExitMessageBox:Destroy
nowexiting:=false
return
ExitMessageBoxTimeout:
settimer,ExitMessageBoxTimeout,off
gui,ExitMessageBox:destroy
return
