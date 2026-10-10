
#Include %a_scriptdir%\..\lib\Yunit\Yunit.ahk
#Include %a_scriptdir%\..\lib\Yunit\Window.ahk
#Include %a_scriptdir%\..\lib\Yunit\StdOut.ahk

#include %a_scriptdir%\..\Source_Main\Globals\Global Variables.ahk


#include main\Globals\test globals.ahk

Yunit.Use(YunitStdOut, YunitWindow).Test(main_Globals_TestSuite)

