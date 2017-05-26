;7z warpper - joedf
;modified by bichlepa

7z_exe:=my_WorkingDir "\bin\7za.exe"
;~ 7z_exe:="C:\Program Files\7-Zip\7z.exe"

7z_compress(dPack, opts, files*) {
	global 7z_exe
	flist:=""
	for each, file in files
		flist:= flist """" file """" " "
	;~ if FileExist(dPack)
		;~ FileDelete, %dPack%
	RunWait, %7z_exe% a %opts% "%dPack%" %flist%,,Hide UseErrorLevel
	return 7z_error(ErrorLevel)
}

7z_extract(dPack,opts="",dFolder="") {
	global 7z_exe
	if StrLen(dFolder)
		out:="-o" . """" . dFolder . """"
	RunWait, %7z_exe% x "%dPack%" %out% -y %opts%,,Hide UseErrorLevel
	return 7z_error(ErrorLevel)
}

7z_list(dPack) {
	global 7z_exe
	tmp:=TempFile()
	RunWait,%comspec% /c %7z_exe% l "%dPack%" > "%tmp%",,Hide UseErrorLevel
	r:={}
	if (!(e:=7z_error(ErrorLevel))) {
		FileRead,o,%tmp%
		Loop, Parse, o, `n, `r
		{
			if (RegExMatch(A_LoopField,"(-+\s+){4}")) {
				if (!i)
					i:=A_Index
				else
					break
			}
			if (A_Index-i > 0) {
				p:=StrSplit(A_LoopField,A_Space)
				RegExMatch(SubStr(A_LoopField,StrLen(p.1 p.2 p.3)+3),"\d+",S)
				c:=InStr(A_LoopField,S)+StrLen(S)
				StringTrimLeft,n,A_LoopField,%c%
				
				k:={}
				k.Date := p.1
				k.Time := p.2
				k.Attr := p.3
				k.Size := S
				k.Name := RegExReplace(n,"\s+\d*\s+","","",1)
				
				r.Insert(k)
			}
		}
	}
	FileDelete,%tmp%
	return (e?0:r)
}

7z_error(e) {
	if (e=0)
		return lang("Success")
	if (e=1)
		return lang("Warning. Probably one or more files were locked by some other application, so they were not compressed.")
	else if (e=2)
		return lang("Fatal error")
	else if (e=7)
		return lang("Command line error")
	else if (e=8)
		return lang("Not enough memory for operation")
	else if (e=255)
		return lang("User stopped the process")
	else if (e="ERROR")
		return lang("7zip not found")
	else
		return lang("unknown error")
}

TempFile() {
	Loop
		tempName := A_Temp "\~temp" A_TickCount ".tmp"
	until !FileExist(tempName)
	return tempName
}