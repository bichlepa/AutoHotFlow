#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

global _AHF_VERSION := "1.1.0"

; do not warn if a continuable exception occurs (it happens often when AHF is closing)
#WarnContinuableException off

; We only want to have one instance of AHF
#SingleInstance,  force

;Using working dir forbidden.
;The reason is that while any thread uses the command FileSelectFile, the working directory of the working directory of the whole process is changed to the path which is shown in the dialog.
SetWorkingDir %a_temp%  

; Set the variable _ScriptDir which is acutally the root folder of AHF. If installed, it is the installation folder.
global _ScriptDir := StrReplace(A_ScriptDir, "\Source_Main") ;The directory of AutoHotFlow.ahk/exe

; Set the variable _WorkingDir which we will always use instead of a_workingDir
;if portable installation, the script dir is the working dir. 
;If installed in programs folder, it is a dir which is writable without admin rights
global _WorkingDir
if FileExist(_ScriptDir "\AppData")
{
	_WorkingDir = %_ScriptDir%\AppData
}
Else
{
	_WorkingDir = %A_AppData%\AutoHotFlow
	if not fileexist(_WorkingDir)
		FileCreateDir, %_WorkingDir%
}

; Make the variable _ahkThreadID super global.
global _ahkThreadID:="Main"

; On call of ExitApp, we will start the exit routine
OnExit,Exit
global _exiting := false

; set default file encoding
FileEncoding utf-8

;Initialize shared variables
gosub, init_SharedVars

; load global settings
load_settings()

;initialize logger
init_logger()
log_enableRegularCleanup()
logger("a1", "startup")

;If AutoHotFlow is started automatically on windows startup.
;This information is passed by command line parameter of the link which is stored in the autorun folder.
; The shared variable WindowsStartup is evaluated by the trigger "start up"
firstCommandLineParameter = %1%
_setShared("WindowsStartup", (firstCommandLineParameter = "WindowsStartup"))
; also set this flag on AHF startup
_setShared("AHFStartup", true)

; include language module
#Include %A_ScriptDir%\..
#include language\language.ahk
_language := Object()
_language.dir := _ScriptDir "\language" ;Directory where the translations are stored
_language.readAll := true
lang_Init()
lang_setLanguage(_settings.UILanguage)

; check the settings
check_settings()

;if setting run as admin active, try to gain administrator rights
if (_getSettings("runAsAdmin") and not A_IsAdmin)
{
	;Use a file to catch if gaining administrator rights fails multiple times
	FileRead, triedtostart, %a_temp%\autoHotflowTryToStartAsAdmin.txt
	IfInString, triedtostart, 111
	{
		MsgBox, 52, , % lang("Several tries to start as administrator failed. Do you want to disable it?")
		IfMsgBox yes
		{
			_setSettings("runAsAdmin", false)
			write_settings()
			skipstartAsAdmin := true
		}
	}
	if not skipstartAsAdmin
	{
		; Restart with administrator rights
		FileAppend, 1, %a_temp%\autoHotflowTryToStartAsAdmin.txt
		try Run *RunAs "%a_ahkPath%" "%A_ScriptFullPath%" ;Run as admin. See https://autohotkey.com/docs/commands/Run.htm#RunAs
		ExitApp
	}
}
;If we reach that line, either no administartor rights are needed, or administrator rights are granted. Therefore remove that file.
FileDelete, %a_temp%\autoHotflowTryToStartAsAdmin.txt

;Some library function includes
#include lib\Objects\Objects.ahk
#include lib\Random Word List\Random Word List.ahk
#include Lib\gdi+\gdip.ahk
#include lib\Json\Jxon.ahk
#include lib\7z wrapper\7z wrapper.ahk

;Include libraries which may be used by the elements. This code is generated.
global global_libInclusionsForThreads, global_elementInclusionsForThreads
;Lib_includes_Start#include source_Elements\Default\lib\TTS\TTS by Learning One.ahk
#include source_Elements\Default\lib\Eject\Eject.ahk
#include source_Elements\Default\lib\Class_Monitor\Class_Monitor.ahk
#include source_Elements\Default\lib\HTTP Request\HTTPRequest.ahk
#include source_Elements\Default\lib\HTTP Request\Uriencode.ahk
#include source_Elements\Default\lib\Process list\getProcessList.ahk
#include source_Elements\Default\lib\Json\Jxon.ahk
#include source_Elements\Default\lib\Yaml\Yaml.ahk
#include source_Elements\Default\common\window functions.ahk

global_libInclusionsForThreads = 
(
#include source_Elements\Default\lib\TTS\TTS by Learning One.ahk
#include source_Elements\Default\lib\Eject\Eject.ahk
#include source_Elements\Default\lib\Class_Monitor\Class_Monitor.ahk
#include source_Elements\Default\lib\HTTP Request\HTTPRequest.ahk
#include source_Elements\Default\lib\HTTP Request\Uriencode.ahk
#include source_Elements\Default\lib\Process list\getProcessList.ahk
#include source_Elements\Default\lib\Json\Jxon.ahk
#include source_Elements\Default\lib\Yaml\Yaml.ahk
#include source_Elements\Default\common\window functions.ahk

)

;Lib_Includes_End

; include all the other source code
#include Source_Main\Tray\Tray.ahk
#include Source_Main\Api\Shared Variables.ahk
#include Source_Main\Threads\Threads.ahk
#include Source_Main\Api\API for Elements.ahk
#include Source_Main\hidden window\hidden window.ahk

#include Source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
#include Source_Common\Flows\Flow actions.ahk
#include Source_Common\Flows\states.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Settings\Settings.ahk
#include source_Common\variables\global variables.ahk
#include source_Common\variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk
#include source_Common\Other\Other.ahk
#include source_Common\Other\Design.ahk

;Include elements. This code is generated
;The elements must be included before the other treads are started
;Element_Includes_Start#include source_Elements\Default\actions\New_Variable.ahk
#include source_Elements\Default\actions\Random_Number.ahk
#include source_Elements\Default\actions\Absolute_Number.ahk
#include source_Elements\Default\actions\Square_Root.ahk
#include source_Elements\Default\actions\Trigonometry.ahk
#include source_Elements\Default\actions\Rounding_a_number.ahk
#include source_Elements\Default\actions\Exponentiation.ahk
#include source_Elements\Default\actions\Search_in_a_string.ahk
#include source_Elements\Default\actions\Substring.ahk
#include source_Elements\Default\actions\Get_string_Length.ahk
#include source_Elements\Default\actions\Replace_in_a_string.ahk
#include source_Elements\Default\actions\Trim_a_string.ahk
#include source_Elements\Default\actions\Split_a_string.ahk
#include source_Elements\Default\actions\Change_character_case.ahk
#include source_Elements\Default\actions\New_List.ahk
#include source_Elements\Default\actions\Add_to_list.ahk
#include source_Elements\Default\actions\Get_from_list.ahk
#include source_Elements\Default\actions\Get_index_of_element_in_list.ahk
#include source_Elements\Default\actions\Get_list_info.ahk
#include source_Elements\Default\actions\Delete_from_list.ahk
#include source_Elements\Default\actions\Convert_list_to_string.ahk
#include source_Elements\Default\actions\Convert_string_to_list.ahk
#include source_Elements\Default\actions\Shuffle_list.ahk
#include source_Elements\Default\actions\New_Time.ahk
#include source_Elements\Default\actions\Time_calculation.ahk
#include source_Elements\Default\actions\Time_difference.ahk
#include source_Elements\Default\actions\Script.ahk
#include source_Elements\Default\actions\Get_Clipboard.ahk
#include source_Elements\Default\actions\Set_Clipboard.ahk
#include source_Elements\Default\actions\Input_Box.ahk
#include source_Elements\Default\actions\Message_Box.ahk
#include source_Elements\Default\actions\Tooltip.ahk
#include source_Elements\Default\actions\Eject_Drive.ahk
#include source_Elements\Default\actions\Change_Drive_Label.ahk
#include source_Elements\Default\actions\Get_Drive_Information.ahk
#include source_Elements\Default\actions\Lock_Or_Unlcock_Drive.ahk
#include source_Elements\Default\actions\List_Drives.ahk
#include source_Elements\Default\actions\Compress_files.ahk
#include source_Elements\Default\actions\Extract_files.ahk
#include source_Elements\Default\actions\Copy_file.ahk
#include source_Elements\Default\actions\Copy_folder.ahk
#include source_Elements\Default\actions\Create_folder.ahk
#include source_Elements\Default\actions\Delete_file.ahk
#include source_Elements\Default\actions\Delete_folder.ahk
#include source_Elements\Default\actions\Empty_Recycle_bin.ahk
#include source_Elements\Default\actions\Get_file_attributes.ahk
#include source_Elements\Default\actions\Get_file_size.ahk
#include source_Elements\Default\actions\Get_file_time.ahk
#include source_Elements\Default\actions\Move_File.ahk
#include source_Elements\Default\actions\Move_Folder.ahk
#include source_Elements\Default\actions\Rename_file.ahk
#include source_Elements\Default\actions\Rename_Folder.ahk
#include source_Elements\Default\actions\Select_file.ahk
#include source_Elements\Default\actions\Select_folder.ahk
#include source_Elements\Default\actions\Set_file_attributes.ahk
#include source_Elements\Default\actions\Set_file_time.ahk
#include source_Elements\Default\actions\Write_To_File.ahk
#include source_Elements\Default\actions\Read_From_File.ahk
#include source_Elements\Default\actions\Read_From_Ini.ahk
#include source_Elements\Default\actions\Delete_From_Ini.ahk
#include source_Elements\Default\actions\Write_to_ini.ahk
#include source_Elements\Default\actions\Download_file.ahk
#include source_Elements\Default\actions\HTTP_Request.ahk
#include source_Elements\Default\actions\Screenshot.ahk
#include source_Elements\Default\actions\Get_pixel_color.ahk
#include source_Elements\Default\actions\Search_pixel.ahk
#include source_Elements\Default\actions\Search_Image.ahk
#include source_Elements\Default\actions\Get_Screen_Settings.ahk
#include source_Elements\Default\actions\Set_Screen_Settings.ahk
#include source_Elements\Default\actions\activate_Window.ahk
#include source_Elements\Default\actions\Show_window.ahk
#include source_Elements\Default\actions\Close_Window.ahk
#include source_Elements\Default\actions\Hide_window.ahk
#include source_Elements\Default\actions\Move_window.ahk
#include source_Elements\Default\actions\Minimize_All_Windows.ahk
#include source_Elements\Default\actions\Get_control_text.ahk
#include source_Elements\Default\actions\Set_control_text.ahk
#include source_Elements\Default\actions\Click.ahk
#include source_Elements\Default\actions\Move_Mouse.ahk
#include source_Elements\Default\actions\Drag_with_mouse.ahk
#include source_Elements\Default\actions\Get_mouse_position.ahk
#include source_Elements\Default\actions\Send_Keystrokes.ahk
#include source_Elements\Default\actions\Send_Keystrokes_To_Control.ahk
#include source_Elements\Default\actions\Set_Lock_Key.ahk
#include source_Elements\Default\actions\Play_Sound.ahk
#include source_Elements\Default\actions\Stop_Sound.ahk
#include source_Elements\Default\actions\Beep.ahk
#include source_Elements\Default\actions\Get_Volume.ahk
#include source_Elements\Default\actions\Set_Volume.ahk
#include source_Elements\Default\actions\Speech_output.ahk
#include source_Elements\Default\actions\Run.ahk
#include source_Elements\Default\actions\Kill_Process.ahk
#include source_Elements\Default\actions\Set_Process_Priority.ahk
#include source_Elements\Default\actions\Lock_Computer.ahk
#include source_Elements\Default\actions\Log_Off.ahk
#include source_Elements\Default\actions\Shutdown.ahk
#include source_Elements\Default\actions\Reboot_Computer.ahk
#include source_Elements\Default\actions\Hibernate_Computer.ahk
#include source_Elements\Default\actions\Suspend_Computer.ahk
#include source_Elements\Default\actions\Sleep.ahk
#include source_Elements\Default\actions\Set_Flow_Status.ahk
#include source_Elements\Default\actions\Execute_Flow.ahk
#include source_Elements\Default\actions\Stop_Flow.ahk
#include source_Elements\Default\actions\AutoHotkey_script.ahk
#include source_Elements\Default\actions\Trace_Point.ahk
#include source_Elements\Default\actions\Trace_Point_Check.ahk
#include source_Elements\Default\conditions\Expression.ahk
#include source_Elements\Default\conditions\Variable_Is_Empty.ahk
#include source_Elements\Default\conditions\List_Contains_Element.ahk
#include source_Elements\Default\conditions\String_Contains_Text.ahk
#include source_Elements\Default\conditions\Number_is.ahk
#include source_Elements\Default\conditions\File_Exists.ahk
#include source_Elements\Default\conditions\File_Has_Attribute.ahk
#include source_Elements\Default\conditions\Confirmation_Dialog.ahk
#include source_Elements\Default\conditions\Debug_dialog.ahk
#include source_Elements\Default\conditions\Key_Is_Down.ahk
#include source_Elements\Default\conditions\Window_Active.ahk
#include source_Elements\Default\conditions\Window_Exists.ahk
#include source_Elements\Default\conditions\Process_Is_Running.ahk
#include source_Elements\Default\conditions\Flow_Enabled.ahk
#include source_Elements\Default\conditions\Flow_Running.ahk
#include source_Elements\Default\loops\SimpleLoop.ahk
#include source_Elements\Default\loops\Condition.ahk
#include source_Elements\Default\loops\Parse_A_String.ahk
#include source_Elements\Default\loops\Work_through_a_list.ahk
#include source_Elements\Default\loops\Loop_Through_Files.ahk
#include source_Elements\Default\triggers\Manual.ahk
#include source_Elements\Default\triggers\Periodic_Timer.ahk
#include source_Elements\Default\triggers\Time_of_Day.ahk
#include source_Elements\Default\triggers\User_Idle_Time.ahk
#include source_Elements\Default\triggers\Clipboard_Changes.ahk
#include source_Elements\Default\triggers\Hotkey.ahk
#include source_Elements\Default\triggers\Shortcut.ahk
#include source_Elements\Default\triggers\Window_opens.ahk
#include source_Elements\Default\triggers\Window_closes.ahk
#include source_Elements\Default\triggers\Window_gets_active.ahk
#include source_Elements\Default\triggers\Window_gets_inactive.ahk
#include source_Elements\Default\triggers\Process_starts.ahk
#include source_Elements\Default\triggers\Process_closes.ahk
#include source_Elements\Default\triggers\Start_up.ahk
#include source_Elements\Default\triggers\AutoHotkey_Script.ahk

global_elementInclusionsForThreads = 
(
#include source_Elements\Default\actions\New_Variable.ahk
#include source_Elements\Default\actions\Random_Number.ahk
#include source_Elements\Default\actions\Absolute_Number.ahk
#include source_Elements\Default\actions\Square_Root.ahk
#include source_Elements\Default\actions\Trigonometry.ahk
#include source_Elements\Default\actions\Rounding_a_number.ahk
#include source_Elements\Default\actions\Exponentiation.ahk
#include source_Elements\Default\actions\Search_in_a_string.ahk
#include source_Elements\Default\actions\Substring.ahk
#include source_Elements\Default\actions\Get_string_Length.ahk
#include source_Elements\Default\actions\Replace_in_a_string.ahk
#include source_Elements\Default\actions\Trim_a_string.ahk
#include source_Elements\Default\actions\Split_a_string.ahk
#include source_Elements\Default\actions\Change_character_case.ahk
#include source_Elements\Default\actions\New_List.ahk
#include source_Elements\Default\actions\Add_to_list.ahk
#include source_Elements\Default\actions\Get_from_list.ahk
#include source_Elements\Default\actions\Get_index_of_element_in_list.ahk
#include source_Elements\Default\actions\Get_list_info.ahk
#include source_Elements\Default\actions\Delete_from_list.ahk
#include source_Elements\Default\actions\Convert_list_to_string.ahk
#include source_Elements\Default\actions\Convert_string_to_list.ahk
#include source_Elements\Default\actions\Shuffle_list.ahk
#include source_Elements\Default\actions\New_Time.ahk
#include source_Elements\Default\actions\Time_calculation.ahk
#include source_Elements\Default\actions\Time_difference.ahk
#include source_Elements\Default\actions\Script.ahk
#include source_Elements\Default\actions\Get_Clipboard.ahk
#include source_Elements\Default\actions\Set_Clipboard.ahk
#include source_Elements\Default\actions\Input_Box.ahk
#include source_Elements\Default\actions\Message_Box.ahk
#include source_Elements\Default\actions\Tooltip.ahk
#include source_Elements\Default\actions\Eject_Drive.ahk
#include source_Elements\Default\actions\Change_Drive_Label.ahk
#include source_Elements\Default\actions\Get_Drive_Information.ahk
#include source_Elements\Default\actions\Lock_Or_Unlcock_Drive.ahk
#include source_Elements\Default\actions\List_Drives.ahk
#include source_Elements\Default\actions\Compress_files.ahk
#include source_Elements\Default\actions\Extract_files.ahk
#include source_Elements\Default\actions\Copy_file.ahk
#include source_Elements\Default\actions\Copy_folder.ahk
#include source_Elements\Default\actions\Create_folder.ahk
#include source_Elements\Default\actions\Delete_file.ahk
#include source_Elements\Default\actions\Delete_folder.ahk
#include source_Elements\Default\actions\Empty_Recycle_bin.ahk
#include source_Elements\Default\actions\Get_file_attributes.ahk
#include source_Elements\Default\actions\Get_file_size.ahk
#include source_Elements\Default\actions\Get_file_time.ahk
#include source_Elements\Default\actions\Move_File.ahk
#include source_Elements\Default\actions\Move_Folder.ahk
#include source_Elements\Default\actions\Rename_file.ahk
#include source_Elements\Default\actions\Rename_Folder.ahk
#include source_Elements\Default\actions\Select_file.ahk
#include source_Elements\Default\actions\Select_folder.ahk
#include source_Elements\Default\actions\Set_file_attributes.ahk
#include source_Elements\Default\actions\Set_file_time.ahk
#include source_Elements\Default\actions\Write_To_File.ahk
#include source_Elements\Default\actions\Read_From_File.ahk
#include source_Elements\Default\actions\Read_From_Ini.ahk
#include source_Elements\Default\actions\Delete_From_Ini.ahk
#include source_Elements\Default\actions\Write_to_ini.ahk
#include source_Elements\Default\actions\Download_file.ahk
#include source_Elements\Default\actions\HTTP_Request.ahk
#include source_Elements\Default\actions\Screenshot.ahk
#include source_Elements\Default\actions\Get_pixel_color.ahk
#include source_Elements\Default\actions\Search_pixel.ahk
#include source_Elements\Default\actions\Search_Image.ahk
#include source_Elements\Default\actions\Get_Screen_Settings.ahk
#include source_Elements\Default\actions\Set_Screen_Settings.ahk
#include source_Elements\Default\actions\activate_Window.ahk
#include source_Elements\Default\actions\Show_window.ahk
#include source_Elements\Default\actions\Close_Window.ahk
#include source_Elements\Default\actions\Hide_window.ahk
#include source_Elements\Default\actions\Move_window.ahk
#include source_Elements\Default\actions\Minimize_All_Windows.ahk
#include source_Elements\Default\actions\Get_control_text.ahk
#include source_Elements\Default\actions\Set_control_text.ahk
#include source_Elements\Default\actions\Click.ahk
#include source_Elements\Default\actions\Move_Mouse.ahk
#include source_Elements\Default\actions\Drag_with_mouse.ahk
#include source_Elements\Default\actions\Get_mouse_position.ahk
#include source_Elements\Default\actions\Send_Keystrokes.ahk
#include source_Elements\Default\actions\Send_Keystrokes_To_Control.ahk
#include source_Elements\Default\actions\Set_Lock_Key.ahk
#include source_Elements\Default\actions\Play_Sound.ahk
#include source_Elements\Default\actions\Stop_Sound.ahk
#include source_Elements\Default\actions\Beep.ahk
#include source_Elements\Default\actions\Get_Volume.ahk
#include source_Elements\Default\actions\Set_Volume.ahk
#include source_Elements\Default\actions\Speech_output.ahk
#include source_Elements\Default\actions\Run.ahk
#include source_Elements\Default\actions\Kill_Process.ahk
#include source_Elements\Default\actions\Set_Process_Priority.ahk
#include source_Elements\Default\actions\Lock_Computer.ahk
#include source_Elements\Default\actions\Log_Off.ahk
#include source_Elements\Default\actions\Shutdown.ahk
#include source_Elements\Default\actions\Reboot_Computer.ahk
#include source_Elements\Default\actions\Hibernate_Computer.ahk
#include source_Elements\Default\actions\Suspend_Computer.ahk
#include source_Elements\Default\actions\Sleep.ahk
#include source_Elements\Default\actions\Set_Flow_Status.ahk
#include source_Elements\Default\actions\Execute_Flow.ahk
#include source_Elements\Default\actions\Stop_Flow.ahk
#include source_Elements\Default\actions\AutoHotkey_script.ahk
#include source_Elements\Default\actions\Trace_Point.ahk
#include source_Elements\Default\actions\Trace_Point_Check.ahk
#include source_Elements\Default\conditions\Expression.ahk
#include source_Elements\Default\conditions\Variable_Is_Empty.ahk
#include source_Elements\Default\conditions\List_Contains_Element.ahk
#include source_Elements\Default\conditions\String_Contains_Text.ahk
#include source_Elements\Default\conditions\Number_is.ahk
#include source_Elements\Default\conditions\File_Exists.ahk
#include source_Elements\Default\conditions\File_Has_Attribute.ahk
#include source_Elements\Default\conditions\Confirmation_Dialog.ahk
#include source_Elements\Default\conditions\Debug_dialog.ahk
#include source_Elements\Default\conditions\Key_Is_Down.ahk
#include source_Elements\Default\conditions\Window_Active.ahk
#include source_Elements\Default\conditions\Window_Exists.ahk
#include source_Elements\Default\conditions\Process_Is_Running.ahk
#include source_Elements\Default\conditions\Flow_Enabled.ahk
#include source_Elements\Default\conditions\Flow_Running.ahk
#include source_Elements\Default\loops\SimpleLoop.ahk
#include source_Elements\Default\loops\Condition.ahk
#include source_Elements\Default\loops\Parse_A_String.ahk
#include source_Elements\Default\loops\Work_through_a_list.ahk
#include source_Elements\Default\loops\Loop_Through_Files.ahk
#include source_Elements\Default\triggers\Manual.ahk
#include source_Elements\Default\triggers\Periodic_Timer.ahk
#include source_Elements\Default\triggers\Time_of_Day.ahk
#include source_Elements\Default\triggers\User_Idle_Time.ahk
#include source_Elements\Default\triggers\Clipboard_Changes.ahk
#include source_Elements\Default\triggers\Hotkey.ahk
#include source_Elements\Default\triggers\Shortcut.ahk
#include source_Elements\Default\triggers\Window_opens.ahk
#include source_Elements\Default\triggers\Window_closes.ahk
#include source_Elements\Default\triggers\Window_gets_active.ahk
#include source_Elements\Default\triggers\Window_gets_inactive.ahk
#include source_Elements\Default\triggers\Process_starts.ahk
#include source_Elements\Default\triggers\Process_closes.ahk
#include source_Elements\Default\triggers\Start_up.ahk
#include source_Elements\Default\triggers\AutoHotkey_Script.ahk

)

;Element_Includes_End

;Start other threads. Multi-threading gain the performance heavily
;and execution of flows does not lower the GUI performance.
Thread_init()
Thread_StartManager()
Thread_StartDraw()
Thread_StartExecution()

;Find saved flows and enable triggers depending on the settings
FindFlows()
EnableLoadedFlows()

;Refill the treeview of the manager
API_manager_TreeView_Refill()

;Now since the triggers "Start up" have triggered. We don't need those flags anymore.
_setShared("WindowsStartup", false)
_setShared("AHFStartup", false)

;Initialize a hidden command window. This window is able to receive commands from other processes.
;The first purpose is that the script AutoHotFlow.ahk/exe can send commands if a shortcut of the trigger "shortcut" is opened.
CreateHiddenCommandWindow()

;Check whether there is a command passed with the start parameters
command = %1%
commandMessage = %2%
if (command = "AHFCommand")
{
	; we process the command as if it was passed in the hidden command window
	HiddenCommandWindowProcessMessage(commandMessage)
}

; check regularly for new tasks which we get through shared variable
SetTimer,queryTasks,100
return

; Checks for new tasks which can be sent to this AHK thread by writing the task instructions in a shared variable
queryTasks()
{
	global
	Loop
	{
		oneTask := _getTask("main")
		if (oneTask)
		{
			name := oneTask.name
			if (name = "exit")
			{
				; The app should exit. start the exit routine
				exitapp
			}
			if (name = "ahkThreadStopped")
			{
				; An ahk thread has stopped, clean up after that
				thread_Stopped(oneTask.ThreadID)
			}
			if (name = "StartEditor")
			{
				; The editor for a flow should be opened
				if (ThreadEditor_exists(oneTask.FlowID))
				{
					API_Editor_EditGUIshow(oneTask.FlowID)
				}
				Else
				{
					Thread_StartEditor(oneTask.FlowID)
				}
			}
			if (name = "StartElementAhkThread")
			{
				Thread_StartElemenThread(oneTask.UniqueID, oneTask.code, oneTask.notifyWhenStopped)
			}
			if (name = "StopElementAhkThread")
			{
				Thread_StopElemenThread(oneTask.UniqueID)
			}
			if (name = "elementAhkThreadStopped")
			{
				thread_Stopped("element_" oneTask.UniqueID)
			}
			if (name = "elementAhkThreadTrigger")
			{
				API_Execution_externalTrigger(oneTask.UniqueID, oneTask.iteration)
			}
		}
		else
		{
			; There is no task in shared memory. We can now return and save the cpu time until next timer event
			break
		}
	}
}


; Start the exit routine
FinallyExit:
exit:
if (_exiting != true) ;Prevent multiple execution of this code by setting this flag
{
	_exiting := true
	;Save unsaved flows.
	i_SaveUnsavedFlows()

	; stop all element threads
	Thread_stopAllElementThreads()

	; tell other ahk threads that they must close
	; (especially stop entering critical sections. If a thread exits while it is in a critical section, other threads will freeze)
	EnterCriticalSection(_cs_shared)
	_share.exiting := true
	LeaveCriticalSection(_cs_shared)

	; before we start killing the threads (which is error prone), we will give them some time to close
	settimer, exit, 4000
	return
}
Thread_KillAll() ;Kill all other threads
ExitApp
