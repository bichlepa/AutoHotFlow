;Find all languages
lang_FindAllLanguages()
{
	global
	allLangs:=Object()

	Loop,language\*.ini
	{
		
		StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
		
		IniRead,%filenameNoExt%enlangname,language\%filenameNoExt%.ini,general,enname
		IniRead,%filenameNoExt%langname,language\%filenameNoExt%.ini,general,name
		IniRead,%filenameNoExt%code,language\%filenameNoExt%.ini,general,code
		if %filenameNoExt%enlangname!=Error
		{
			
			allLangs.insert(filenameNoExt)
			
		}
		
		;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
	}


	iniread,UILang,settings.ini,common,UILanguage
	if uilang=error
	{
		
		for index, templang in allLangs
		{
			;MsgBox % templang " " %templang%code " " A_Language
			IfInString,%templang%code,%A_Language%
			{
				uilang:=templang
				break
			}
		}
		if uilang=Error
			uilang=en
	}
	IniRead,%UILang%enlangname,language\%UILang%.ini\general\enname
	IniRead,%UILang%langname,language\%UILang%.ini\general\name
	
}

lang(langvar,$1="",$2="",$3="",$4="",$5="",$6="",$7="",$8="",$9="")
{
	global UILang
	global developing
	global translationto
	static guiCreated
	global allLangs
	
	if (langvar ="")
		return ""
	langaborted:=false
	StringReplace,langvar_no_spaces,langvar,%a_space%,_,all
	
	langBeginAgain:
	IniRead,initext,language\%UILang%.ini,translations,%langvar_no_spaces%
	if (initext="" or initext=="ERROR")
	{
		;iniwrite,% "",language\%UILang%.ini,translations,%langvar_no_spaces%
		
		IniRead,initexten,language\en.ini,translations,%langvar_no_spaces%
		;MsgBox %initexten%, %langvar_no_spaces%
		if (initexten=="ERROR" or initexten="") 
		{
			
			if developing=yes
			{
				StringReplace,langvarSpaces,langvar_no_spaces,_,%A_Space%,all
				;MsgBox %langvar_no_spaces%
				InputBox,newtrans,How is this in English?,%langvar_no_spaces%,,,,,,,,%langvarSpaces%
				if ErrorLevel
				{
					IniDelete,language\en.ini,translations,%langvar_no_spaces%
					return
				}
				loop,9
				{
					StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%$,`%1`%,all
					StringReplace,newtrans,newtrans,`%%a_index%$,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%`%,`%1`%,all
					
				}
				iniwrite,% newtrans,language\en.ini,translations,%langvar_no_spaces%
				goto,langBeginAgain
			}
			else
				MsgBox,English text for %langvar_no_spaces% not found!
		}
		else if (translationto=UILang and langaborted=!true)
		{
			temptlangText=
			for tempindex, templang in allLangs
			{
				
				IniRead,templangcont,language\%templang%.ini,translations,%langvar_no_spaces%,%A_Space%
				;MsgBox %templang% %templangcont%
				if templangcont
					temptlangText:=temptlangText "`n" %templang%enlangname ": " templangcont
				
			}
			
			InputBox,newtrans,% "How is this in " %UILang%enlangname "?" ,%langvar_no_spaces% `n%temptlangText%,,% A_ScreenWidth*0.9,% A_ScreenHeight*0.9
			if errorlevel
				langaborted:=true
			else
			{
				loop,9
				{
					
					
					StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%$,`%1`%,all
					StringReplace,newtrans,newtrans,`%%a_index%$,`%1`%,all
					StringReplace,newtrans,newtrans,$%a_index%`%,`%1`%,all
					
				}
				iniwrite,% newtrans,language\%UILang%.ini,translations,%langvar_no_spaces%
				if ErrorLevel
				{
					IniDelete,language\%UILang%.ini,translations,%langvar_no_spaces%
					return
				}
			}
			goto,langBeginAgain
		
		}
		else 
		{
			initext:=initextEN
			
		}
	}
	langSuccess:
	StringReplace,initext,initext,`%1`%,%$1%,all
	StringReplace,initext,initext,`%2`%,%$2%,all
	StringReplace,initext,initext,`%3`%,%$3%,all
	StringReplace,initext,initext,`%4`%,%$4%,all
	StringReplace,initext,initext,`%5`%,%$4%,all
	StringReplace,initext,initext,`%6`%,%$4%,all
	StringReplace,initext,initext,`%7`%,%$4%,all
	StringReplace,initext,initext,`%8`%,%$4%,all
	StringReplace,initext,initext,`%9`%,%$4%,all
	
	
	return initext
	
}
/*
LangImport()
{
	global
	Hotkey,ifwinactive
	Hotkey,f12,langnewWord
	
}

goto,jumpOverlangnewWord

langnewWord:
send,^c
sleep,20
langtemp=false
StringReplace,clipboard,clipboard,%a_space%,_,all
StringReplace,clipboard,clipboard,`",,all
if not errorlevel
	langtemp=true
StringReplace,clipboard,clipboard,(,,all
if not errorlevel
	langtemp=true
StringReplace,clipboard,clipboard,),,all
if not errorlevel
	langtemp=true
lang(Clipboard)
;~ if langtemp=true
	clipboard:="lang(""" clipboard """)"
;~ else
	;~ clipboard:="`% lang(""" clipboard """)"
	
ToolTip(clipboard,1000)
return

jumpOverlangnewWord:
temp=
*/
