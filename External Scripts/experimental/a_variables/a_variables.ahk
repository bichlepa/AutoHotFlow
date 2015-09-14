MODIFIED=20150223
 
;-http://ahkscript.org/boards/viewtopic.php?f=5&t=1615
 
;---------------------------------------
; small Listview example with 3 columns
; - doubleclick > start program
;   tagx clsidx a_variablex
 
;----------modifications:
; - added CLSID
; - Gui / Listview height depending A_screenheight
;---------------------------------------
 
#NoEnv              ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input      ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir, %A_ScriptDir%
SetTitleMatchMode 2
SetBatchLines, -1
 
FormatTime, Suomi , L1035, dddd MMMM yyyy-MM-dd
Filename1=AHK-A_Variables      User=%a_username%        Computer=%a_computername%        %a_osversion%       AHK-Version=%a_ahkversion%       %suomi%
 
url=http://www.netikus.net/show_ip.html   ;- to show public IP-address
Adr:= UrlDownloadToVar( URL )             ;- desactivate this when no internetconnection
 
LH :=(A_screenheight*92)/100  ;- LV  height
GH :=(A_screenheight*94)/100  ;- GUI height
 
e4x=
(
__MyComputer,CLSID,::{20d04fe0-3aea-1069-a2d8-08002b30309d}
__MyNetworkPlaces,CLSID,::{208d2c60-3aea-1069-a2d7-08002b30309d}
__NetworkConnections,CLSID,::{7007acc7-3202-11d1-aad2-00805fc1270e}
__Printers,CLSID,::{2227a280-3aea-1069-a2de-08002b30309d}
__RecycleBin,CLSID,::{645ff040-5081-101b-9f08-00aa002f954e}
__ScheduledTasks,CLSID,::{d6277990-4c6a-11cf-8d87-00aa0060f5bf}
_ahk-Version,a_ahkversion,%a_ahkversion%
_unicode,a_IsUnicode,%a_IsUnicode%
_ipaddress-1 private,a_ipaddress1,%a_ipaddress1%
_ipaddress-2,a_ipaddress2,%a_ipaddress2%
_ipaddress-3,a_ipaddress3,%a_ipaddress3%
_ipaddress-4,a_ipaddress4,%a_ipaddress4%
_ipaddress-0 public,www.netikus.net,%adr%
__64-bit,a_Is64bitOS,%a_Is64bitOS%
ahk-path,a_ahkpath,%a_ahkpath%
ahk-scriptfullpath,a_scriptfullpath,%a_scriptfullpath%
_ahk-HWND,a_scriptHwnd,%a_scriptHwnd%
_ptr-size,a_ptrsize,%a_ptrsize%
appdata,a_appdata,%a_appdata%
appdatacommon,a_appdatacommon,%A_appdatacommon%
personal mydocuments,a_mydocuments,%A_mydocuments%
programfiles,a_programfiles,%A_programfiles%
programs,a_programs,%A_programs%
programsCommon,a_programsCommon,%A_programsCommon%
start Menu,a_StartMenu,%A_StartMenu%
startMenuCommon,a_StartMenuCommon,%a_StartMenuCommon%
startup,a_Startup,%A_Startup%
startupCommon,a_StartupCommon,%A_StartupCommon%
temp,a_Temp,%A_Temp%
_username,a_username,%A_username%
_DATE,a_YYYY-A_MM-a_DD a_hour:a_min:a_sec,%A_YYYY%-%A_MM%-%a_DD% %a_hour%:%a_min%:%a_sec%
_DATE_NOW,a_now,%a_now%
_DATE_UTC,a_nowUTC,%a_nowUTC%
desktop,a_desktop,%A_desktop%
desktopcommon,a_desktopcommon,%A_desktopcommon%
_computername,a_computername,%A_computername%
windir,a_windir,%a_windir%
_language,a_language,%a_language%
_iconhidden,a_iconhidden,%a_iconhidden%
ahk-scriptworkingdir,a_workingdir,%a_workingdir%
admin,a_IsAdmin,%a_IsAdmin%
_osType,a_OsType,%a_OsType%
_osversion,a_osversion,%a_osversion%
 
)
 
e5x:= % ShellFolder()
e6x=%e4x%%e5x%
 
 
Gui,2:default
Gui,2:Font,s10, Lucida Console
Gui,2:Color,Black
 
Gui,2: Add, ListView,grid backgroundTeal cWhite x10 y10 h%LH% w1190 gMyLV1 vLV1 +altsubmit -multi, Name|AHK-A_Variable|Show Result ( open Info/Folder/File with doubleclick )
LV_ModifyCol(1, 200), LV_ModifyCol(2, 160), LV_ModifyCol(3, 800)    ;- column width
 
Gui,2:show,x10 y10 h%gh% w1230,%filename1%
gosub,fillx
return
2Guiclose:
exitapp
;--------------------------
 
fillx:
Gui,2:submit,nohide
Gui,2:ListView, LV1
LV_Delete()
loop,parse,e6x,`n,`r
   {
   y=%a_loopfield%
   if y=
     continue
   LV_Add("", StrSplit(y,",")*)
   }
;LV_ModifyCol(3, "Logical SortDesc")
LV_ModifyCol(1, "Logical SortAsc")
return
;----------------------------
 
mylv1:
Gui,2:ListView, LV1
if A_GuiEvent = Doubleclick
  {
  LV_GetText(C1,A_EventInfo,1)
  LV_GetText(C2,A_EventInfo,2)
  LV_GetText(C3,A_EventInfo,3)
  stringmid,C3a,C3,1,3
  stringmid,C3b,C3,1,2
  if (c3a="C:\" or c3b="::")
    {
    SplitPath,C3,name, dir, ext, name_no_ext, drive
    if ext=
      text1=Want you open =`n%c3% ?
    else
      text1=Want you run =`n%c3% ?
    msgbox, 262180, START,%text1%
    ifmsgbox,NO
       return
    else
       run,%c3%
    return
    }
  else
    {
    msgbox, 262208,INFO ,C1=%c1%`nC2=%c2%`nC3=%c3%
    return
    }
  return
  }
return
;-------------------------------
 
;-------- http://www.autohotkey.com/forum/topic36688.html ---
;MsgBox  % ShellFolder()                  ; To retrieve all
;MsgBox  % ShellFolder( "My Pictures" )   ; To retrieve Pictures folder
;return
 
ShellFolder( VN="" ) {
Static Subkey:="Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
 If ( VN="")
 Loop, HKCU, %SubKey%, 0
    {  VarSetCapacity( Spaces,30,32 )
       RegRead, Value, HKCU, %SubKey%, %A_LoopRegName%
       v .= ((v<>"") ? "`n" : "" ) (A_LoopRegName) ",RegRead," Value
    } Else
 RegRead, V, HKCU, %SubKey%, %VN%
Return V
}
 
 
UrlDownloadToVar(URL) {
 WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
 WebRequest.Open("GET", URL)
 WebRequest.Send()
 Return WebRequest.ResponseText
}
 
;--- notices to CLSID = -C means run is possible
/*
-C_MyComputer,,::{20d04fe0-3aea-1069-a2d8-08002b30309d}
-C_MyDocuments,,::{450d8fba-ad25-11d0-98a8-0800361b1103}
-C_MyNetworkPlaces,,::{208d2c60-3aea-1069-a2d7-08002b30309d}
-C_NetworkConnections,,::{7007acc7-3202-11d1-aad2-00805fc1270e}
-C_Printers,,::{2227a280-3aea-1069-a2de-08002b30309d}
-C_RecycleBin,,::{645ff040-5081-101b-9f08-00aa002f954e}
-C_ScheduledTasks,,::{d6277990-4c6a-11cf-8d87-00aa0060f5bf}
 
C_Administrative Tools,,::{d20ea4e1-3957-11d2-a40b-0c5020524153}
C_Briefcase,,::{85bbd92o-42a0-1o69-a2e4-08002b30309d}
C_Control panel,,::{21ec2o2o-3aea-1o69-a2dd-08002b30309d}
C_Fonts,,::{d20ea4e1-3957-11d2-a40b-0c5020524152}
C_History,,::{ff393560-c2a7-11cf-bff4-444553540000}
C_Inbox,,::{00020d75-0000-0000-c000-000000000046}
C_Network,,::{00028b00-0000-0000-c000-000000000046}
C_NetworkComputers,,::{1f4de370-d627-11d1-ba4f-00a0c91eedba}
C_Programs,,::{7be9d83c-a729-4d97-b5a7-1b7313c39e0a}
C_ScannersCameras,,::{e211b736-43fd-11d1-9efb-0000f8757fcd}
C_StrtMenu,,::{48e7caab-b918-4e58-a94d-505519c795dc}
C_TempInternetFiles,,::{7bd29e00-76c1-11cf-9dd0-00a0c9034933}
C_WebFolders,,::{bdeadf00-c265-11d0-bced-00a0c90ab50f}
*/
;================= END script ===========================
 
 
 