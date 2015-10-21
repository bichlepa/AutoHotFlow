; by jNizM  http://ahkscript.org/boards/viewtopic.php?p=49269#p49269
; Modified by bichlepa

OSInstallDate()
{
    for objItem in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_OperatingSystem")
    {
        
        ;~ FormatTime, InstOS, % SubStr(objItem.InstallDate, 1, 14), % "dd. MMM yyyy - HH:mm"
        ;~ FormatTime, DateFrom, % SubStr(objItem.InstallDate, 1, 14), % "yyyyMMdd"
        ;~ DateTo := A_Now
        ;~ DateTo -= DateFrom, days
        ;~ return InstOS "   |   (" DateTo " days)"
        return SubStr(objItem.InstallDate, 1, 14)
    }
}

;~ MsgBox % OSInstallDate()

