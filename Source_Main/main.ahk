#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
#SingleInstance,  force

;Using working dir forbidden.
;The reason is that while any thread uses the command FileSelectFile, the working directory of the working directory of the whole process is changed to the path which is shown in the dialog.
SetWorkingDir %a_temp%  

;Set some super global variables
global _ahkThreadID:="Main"

SetWorkingDir %A_ScriptDir%\..  ; set working dir, which should be the path of AutoHotFlow.ahk/exe
global _ScriptDir := A_ScriptDir "\.." ;The directory of AutoHotFlow.ahk/exe

;if portable installation, the script dir is the working dir. 
;If installed in programs folder, it is a dir which is writable without admin rights
global _WorkingDir := _ScriptDir
IfInString, _WorkingDir, %A_ProgramFiles%
{
	_WorkingDir = %A_AppData%\AutoHotFlow
	if not fileexist(_WorkingDir)
		FileCreateDir, %_WorkingDir%
}

;Initialize global variables and load the settings
gosub, init_GlobalVars
load_settings()

;If AutoHotFlow is started automatically on windows startup.
;This information is passed by command line parameter of the link which is stored in the autorun folder.
firstCommandLineParameter = %1%
_share.WindowsStartup := (firstCommandLineParameter = "WindowsStartup")

#Include %A_ScriptDir%\.. ;Include path is the directory of AutoHotFlow.ahk/exe

;Initialize language.ahk
#include language\language.ahk
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_settings.UILanguage)

;The logger will allow to log messages
initLog()
logger("a1", "startup")

OnExit,exit ;This will allow to save unsaved flows if AutoHotFlow is closed

;if setting run as admin active, try to gain administrator rights
if (_settings.runAsAdmin and not A_IsAdmin)
{
	;User a file to catch if gaining administrator rights fails multiple times
	FileRead,triedtostart,%a_temp%\autoHotflowTryToStartAsAdmin.txt
	IfInString, triedtostart, 111
	{
		MsgBox, 52, , % lang("Several tries to start as administrator failed. Do you want to disable it?")
		IfMsgBox yes
		{
			_settings.runAsAdmin:=false
			write_settings()
			skipstartAsAdmin :=true
		}
	}
	if not skipstartAsAdmin
	{
		FileAppend,1,%a_temp%\autoHotflowTryToStartAsAdmin.txt
		try Run *RunAs "%A_ScriptFullPath%" ;Run as admin. See https://autohotkey.com/docs/commands/Run.htm#RunAs
		ExitApp
	}
	
	;~ RunAsAdmin()
}
 ;If we reach that line, either no administartor rights are needed, or administrator rights are granted. Therefore remove that file.
FileDelete,%a_temp%\autoHotflowTryToStartAsAdmin.txt

;Some library function includes
#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk
#include Lib\gdi+\gdip.ahk

;Include libraries which may be used by the elements. This code is generated.
;Lib_includes_Start#include lib\7z wrapper\7z wrapper.ahk
	#include Lib\TTS\TTS by Learning One.ahk
	#include Lib\Eject by SKAN\Eject by SKAN.ahk
	#include Lib\Class_Monitor\Class_Monitor.ahk
	#include Lib\HTTP Request\HTTPRequest.ahk
	#include Lib\HTTP Request\Uriencode.ahk
global_elementInclusions = 
(
#include lib\7z wrapper\7z wrapper.ahk
	#include Lib\TTS\TTS by Learning One.ahk
	#include Lib\Eject by SKAN\Eject by SKAN.ahk
	#include Lib\Class_Monitor\Class_Monitor.ahk
	#include Lib\HTTP Request\HTTPRequest.ahk
	#include Lib\HTTP Request\Uriencode.ahk

)

;Lib_Includes_End

;Include sourcecode
#include Source_Main\Tray\Tray.ahk
#include Source_Main\Globals\Global Variables.ahk
#include Source_Main\Threads\Threads.ahk
#include Source_Main\Api\API for Elements.ahk

#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk
;~ #include Source_Main\Threads\API Receiver Main.ahk

#include Source_Main\hidden window\hidden window.ahk

#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
#include Source_Common\Flows\Flow actions.ahk
#include Source_Common\Flows\states.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Settings\Default values.ahk
#include source_Common\Settings\Settings.ahk
#include source_Common\variables\global variables.ahk
#include source_Common\variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk
#include source_Common\Other\Other.ahk

;Include elements. This code is generated
;The elements must be included before the other treads are started
;Element_Includes_Start
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Absolute_Number.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\activate_Window.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Add_to_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\AutoHotkey_script.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Beep.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Change_character_case.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Change_Drive_Label.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Click.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Close_Window.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Compress files.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Copy_file.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Copy_folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Create_folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Date_calculation.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Delete_file.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Delete_folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Delete_From_Ini.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Delete_from_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Download_file.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Drag_with_mouse.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Eject_Drive.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Empty_Recycle_bin.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Execute_Flow.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Exponentiation.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Extract files.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_Clipboard.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_control_text.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_Drive_Information.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_file_attributes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_file_size.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_file_time.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_from_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_index_of_element_in_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_mouse_position.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_pixel_color.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_Screen_Settings.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_string_Length.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Get_Volume.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Hibernate_Computer.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Hide_window.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\HTTP_Request.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Input_Box.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Kill_Process.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\List_Drives.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Lock_Computer.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Lock_Or_Unlcock_Drive.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Log_Off.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Message_Box.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Minimize_All_Windows.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Move_File.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Move_Folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Move_Mouse.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Move_window.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\New_Date.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\New_List.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\New_Variable.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Play_Sound.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Random_Number.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Read_From_File.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Read_From_Ini.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Reboot_Computer.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Rename_file.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Rename_Folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Rounding_a_number.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Run.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Screenshot.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Script.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Search_Image.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Search_in_a_string.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Search_pixel.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Select_file.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Select_folder.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Send_Keystrokes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Send_Keystrokes_To_Control.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Clipboard.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_control_text.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_file_attributes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_file_time.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Flow_Status.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Lock_Key.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Process_Priority.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Screen_Settings.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Set_Volume.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Show_window.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Shuffle_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Shutdown.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Sleep.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Speech_output.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Split_a_string.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Square_Root.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Stop_Flow.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Stop_Sound.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Substring.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Suspend_Computer.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Tooltip.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Trace_Point.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Trace_Point_Check.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Trigonometry.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Trim_a_string.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Write_To_File.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Actions\Write_to_ini.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Confirmation_Dialog.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Debug_dialog.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Expression.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\File_Exists.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\File_Has_Attribute.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Flow_Enabled.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Flow_Running.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Key_Is_Down.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\List_Contains_Element.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Process_Is_Running.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\String_Contains_Text.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Variable_Is_Empty.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Window_Active.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Conditions\Window_Exists.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Loops\Condition.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Loops\Loop_Through_Files.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Loops\Parse_A_String.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Loops\SimpleLoop.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Loops\Work_through_a_list.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Clipboard_Changes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Hotkey.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Manual.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Periodic_Timer.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Process_closes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Process_starts.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Shortcut.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Start_up.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Time_of_Day.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\User_Idle_Time.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Window_closes.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Window_gets_active.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Window_gets_inactive.ahk
#include C:\Users\bichl\Documents\git\AutoHotFlow\source_Elements\Default\Triggers\Window_opens.ahk

;Element_Includes_End




;Start other threads. Multi-threading gain the performance hevily
;and execution of flows does not influence the GUI performance.
Thread_init()
Thread_StartManager()
Thread_StartDraw()
Thread_StartExecution()

;Find saved flows and activate triggers of active flows
FindFlows()

;Now the triggers "Startup" have triggered. We don't need this flag anymore.
_share.WindowsStartup:=false

;Initialize a hidden command window. This window is able to receive commands from other processes.
;The first purpose is that the script AutoHotFlow.ahk/exe can send commands if a shortcut of the trigger "shortcut" is opened.
CreateHiddenCommandWindow()

;Do some tasks which were commissioned from other threads 
SetTimer,queryTasks,100
return

queryTasks()
{
	global
	Loop
	{
		oneTask:=_share.main.Tasks.removeat(1)
		if (oneTask)
		{
			name:=oneTask.name
			if (name="exit")
			{
				exitapp
			}
			if (name="ahkThreadStopped")
			{
				thread_Stopped(oneTask.ThreadID)
			}
			if (name="StartEditor")
			{
				Thread_StartEditor(oneTask.FlowID)
			}
		}
		else
			break
	}
}



;This function can be called by all threads. It will close AutoHotFlow.
exit()
{
	;Only set timer in order to return. This is needed if the function is called from other thread.
	SetTimer,exitLabel,-10
}

exitLabel:
ExitApp ;Because we used "OnExit,exit" this command will cause the label "exit" to execute. 
return

exit:
global _exitingNow ;Make this variable super global

if (_exitingNow!=true) ;Prevent multiple execution of this code by setting this flag
{
	_exitingNow:=true
	
	i_SaveUnsavedFlows() ;Save unsaved flows.
	
	Thread_StopAll() ;Stop all other threads
}
ExitApp
