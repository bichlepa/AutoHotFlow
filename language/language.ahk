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

	lang_LoadCurrentLanguage()
	
	
}

lang_LoadCurrentLanguage()
{
	global
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
	IniRead,%UILang%enlangname,language\%UILang%.ini,general,enname
	IniRead,%UILang%langname,language\%UILang%.ini,general,name
	lang_ReadAllTranslations()
}

;translate one string
lang(langvar,$1="",$2="",$3="",$4="",$5="",$6="",$7="",$8="",$9="")
{
	global UILang
	global developing
	global translationto
	global LangNoUseCache
	static guiCreated
	global allLangs
	
	global langAllTranslations
	
	if (langvar ="")
		return ""
	if not isobject(langAllTranslations)
		langAllTranslations:=Object()
	
	langaborted:=false
	StringReplace,langvar_no_spaces,langvar,%a_space%,_,all
	
	langBeginAgain:
	;look whether the string is in cache
	if ((!(LangNoUseCache)) and (langAllTranslations.haskey(langvar_no_spaces)))
	{
		;~ MsgBox %langvar_no_spaces%
		initext:=langAllTranslations[langvar_no_spaces]
		UsedCache:=true
	}
	else ;if not in cache or cache should not be used, read from ini
	{
		IniRead,iniAllSections,language\%UILang%.ini
		Loop,parse,iniAllSections,`n
		{
			IniRead,initext,language\%UILang%.ini,%a_loopfield%,%langvar_no_spaces%,%A_Space%
			if initext
				break
		}
		
		UsedCache:=false
		;~ MsgBox read '%langvar_no_spaces%' from ini
	}
	
	if (initext="")
	{
		;iniwrite,% "",language\%UILang%.ini,translations,%langvar_no_spaces%
		
		IniRead,iniAllSections,language\en.ini
		Loop,parse,iniAllSections,`n
		{
			IniRead,initexten,language\en.ini,%a_loopfield%,%langvar_no_spaces%,%A_Space%
			if initexten
				break
		}
		
		;MsgBox %initexten%, %langvar_no_spaces%
		if (initexten="") 
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
			else if (Lang_NotNotifyIfNoTranslationFound!=true)
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
	else if not UsedCache
	{
		langAllTranslations[langvar_no_spaces]:=initext
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

lang_ReadAllTranslations()
{
	global UILang
	global langAllTranslations
	global langMakeAdditionalCategoryOfTranslationObject
	
	
	langAllTranslations:=Object()
	if langMakeAdditionalCategoryOfTranslationObject
		global langCategoryOfTranslation:=object()
	
	loop,read,language\%UILang%.ini
	{
		
		ifinstring,a_loopreadline,[
			ifinstring,a_loopreadline,]
			{
				tempCategory:=trim(a_loopreadline) ;Remove spaces (if any)
				tempCategory:=trim(a_loopreadline,"[]") ;remove brackets
			}
		
		if tempCategory=general
			continue
		
		ifinstring,a_loopreadline,=
		{
			;~ MsgBox %a_loopreadline%
			stringgetpos,pos,a_loopreadline,=
			stringleft,tempItemName,a_loopreadline,%pos%
			
			StringTrimLeft,tempItemContent,a_loopreadline,% (pos +1)
			
			langAllTranslations[tempItemName]:=tempItemContent
			if langMakeAdditionalCategoryOfTranslationObject
			{
				langCategoryOfTranslation[tempItemName]:=tempCategory
				;~ MsgBox % strobj(langCategoryOfTranslation)
			}
			
			
			
			
		}
		
	}
}