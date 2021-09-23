/*
license info:
{
	"name": "Eject",
	"author": "SKAN",
	"source": "https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4491",
	"license": "public domain",
	"licenselink": "https://creativecommons.org/publicdomain/zero/1.0/legalcode"
}
*/

Default_Lib_Eject( DRV  ) {                       ;  By SKAN,  http://goo.gl/pUUGRt,  CD:01/Sep/2014 | MD:13/Sep/2014
Local hMod, hVol, queryEnum, VAR := "", sPHDRV := "", nDID := 0, nVT := 1, nTC := A_TickCount 
Local IOCTL_STORAGE_GET_DEVICE_NUMBER := 0x2D1080, STORAGE_DEVICE_NUMBER,  FILE_DEVICE_DISK := 0x00000007 
 
  DriveGet, VAR, Type, % DRV := SubStr( DRV, 1, 1 ) ":"
  If ( VAR = "" )
     Return  ( ErrorLevel := -1 ) + 1
 
  If ( VAR = "CDROM" ) {
     Drive, Eject, %DRV%  
     If ( nTC + 1000 > A_Tickcount ) 
        Drive, Eject, %DRV%, 1
     Return  ( ErrorLevel ? 0 : 1 )
  } 
 
; Find physical drive number from drive letter.   
  hVol := DllCall( "CreateFile", "Str","\\.\" DRV, "Int",0, "Int",0, "Int",0, "Int",3, "Int",0, "Int",0 )
 
  VarSetcapacity( STORAGE_DEVICE_NUMBER, 12, 0 )
  DllCall( "DeviceIoControl", "Ptr",hVol, "UInt",IOCTL_STORAGE_GET_DEVICE_NUMBER
         , "Int",0, "Int",0, "Ptr",&STORAGE_DEVICE_NUMBER, "Int",12, "PtrP",0, "Ptr",0 )  
 
  DllCall( "CloseHandle", "Ptr",hVol )
 
  If (  NumGet( STORAGE_DEVICE_NUMBER, "UInt" ) = FILE_DEVICE_DISK  ) 
     sPHDRV := "\\\\.\\PHYSICALDRIVE" NumGet( STORAGE_DEVICE_NUMBER, 4, "UInt" )
 
; Find PNPDeviceID = USBSTOR for given physical drive
  queryEnum := ComObjGet( "winmgmts:" ).ExecQuery( "Select * from Win32_DiskDrive "
                      . "where DeviceID='" sPHDRV "' and InterfaceType='USB'" )._NewEnum()
  If not queryEnum[ DRV ]
     Return ( ErrorLevel := -2 ) + 2
 
  hMod := DllCall( "LoadLibrary", "Str","SetupAPI.dll", "UPtr" )
 
; Locate USBSTOR node and move up to its parent
  DllCall( "SetupAPI\CM_Locate_DevNode", "PtrP",nDID, "Str",DRV.PNPDeviceID, "Int",0 )
  DllCall( "SetupAPI\CM_Get_Parent", "PtrP",nDID, "UInt",nDID, "Int",0 )
 
  VarSetCapacity( VAR, 520, 0 )
  While % ( nDID and nVT and A_Index < 4 ) 
    DllCall( "SetupAPI\CM_Request_Device_Eject", "UInt",nDID, "PtrP",nVT, "Str",VAR, "Int",260, "Int",0 )
 
  DllCall("FreeLibrary", "Ptr",hMod ),    DllCall( "SetLastError", "UInt",nVT )     
 
Return ( nVT ? ( ErrorLevel := -3 ) + 3 : 1 )  
}
