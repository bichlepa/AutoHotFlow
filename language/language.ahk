;Find all languages
;_language := Object()

lang_Init(directory := "::default::", settingsdir := "::default::")
{
	global _language
	if not isobject(_language)
		_language:=Object()
	_language.allLangs:=Object()
	
	if (directory = "::default::")
		directory:= A_ScriptDir "\language"
	_language.dir:=directory
	if (settingsdir = "::default::")
		settingsdir := A_ScriptDir
	_language.settingsdir:=settingsdir

	Loop,%directory%\*.ini
	{
		
		StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
		IniRead,temp,%directory%\%filenameNoExt%.ini,general,enname
		_language[filenameNoExt].enlangname := temp
		IniRead,temp,%directory%\%filenameNoExt%.ini,general,name
		_language[filenameNoExt].langname := temp
		IniRead,temp,%directory%\%filenameNoExt%.ini,general,code
		_language[filenameNoExt].code := temp
		if (_language[filenameNoExt].enlangname != "Error")
		{
			_language.allLangs.insert(filenameNoExt)
		}
		
		;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
	}

	lang_LoadCurrentLanguage()
	
 ;~ d(_language,43877)
}

lang_LoadCurrentLanguage()
{
	global _language
	settingsdir := _language.settingsdir
	;~ MsgBox %settingsdir%
	iniread,UILang,%settingsdir%\settings.ini,common,UILanguage
	_language.UILang := uilang
	directory := _language.dir
	if uilang=error
	{
		for index, templang in _share.allLangs
		{
			;MsgBox % templang " " %templang%code " " A_Language
			tempstring := _language[templang].code
			IfInString, tempstring, %A_Language%
			{
				_language.UILang := templang
				break
			}
		}
		if (_language.UILang="Error")
			(_language.UILang="en")
	}
	IniRead,temp,%directory%\%UILang%.ini,general,enname
	_language[filenameNoExt].enlangname := temp
	IniRead,temp,%directory%\%UILang%.ini,general,name
	_language[filenameNoExt].langname := temp
	lang_ReadAllTranslations()
}

;translate one string
lang(langvar,$1="",$2="",$3="",$4="",$5="",$6="",$7="",$8="",$9="")
{
	static guiCreated
	global _language, developing
	;~ d(_language,456)
	UILang := _language.UILang
	LangNoUseCache := _language.NoUseCache
	directory := _language.dir
	
	if (langvar ="")
		return ""
	if not isobject(_language.cache)
		_language.cache:=Object()
	
	langaborted:=false
	StringReplace,langvar_no_spaces,langvar,%a_space%,_,all
	
	langBeginAgain:
	;look whether the string is in cache
	if ((!(LangNoUseCache)) and (_language.cache.haskey(langvar_no_spaces)))
	{
		;~ MsgBox %langvar_no_spaces%
		initext:=_language.cache[langvar_no_spaces]
		UsedCache:=true
	}
	else ;if not in cache or cache should not be used, read from ini
	{
		IniRead,iniAllSections,%directory%\%UILang%.ini
		Loop,parse,iniAllSections,`n
		{
			IniRead,initext,%directory%\%UILang%.ini,%a_loopfield%,%langvar_no_spaces%,%A_Space%
			if initext
				break
		}
		
		UsedCache:=false
		;~ MsgBox read '%langvar_no_spaces%' from ini
	}
	
	if (initext="")
	{
		;iniwrite,% "",%directory%\%UILang%.ini,translations,%langvar_no_spaces%
		
		IniRead,iniAllSections,%directory%\en.ini
		Loop,parse,iniAllSections,`n
		{
			IniRead,initexten,%directory%\en.ini,%a_loopfield%,%langvar_no_spaces%,%A_Space%
			if initexten
				break
		}
		
		;~ MsgBox %initexten%, %langvar_no_spaces%
		if (initexten="") 
		{
			
			if developing=yes
			{
				StringReplace,langvarSpaces,langvar_no_spaces,_,%A_Space%,all
				;MsgBox %langvar_no_spaces%
				InputBox,newtrans,How is this in English?,%langvar_no_spaces%,,,,,,,,%langvarSpaces%
				if ErrorLevel
				{
					IniDelete,%directory%\en.ini,translations,%langvar_no_spaces%
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
				iniwrite,% newtrans,%directory%\en.ini,translations,%langvar_no_spaces%
				goto,langBeginAgain
			}
			else 
			{
				;~ if (Lang_NotNotifyIfNoTranslationFound!=true)
					;~ MsgBox,English text for %langvar_no_spaces% not found!
				
				;If no translation was found, just insert the raw text
				initext := langvar
			}
			
		}
		else if (translationto=UILang and langaborted=!true)
		{
			temptlangText=
			for tempindex, templang in _share.allLangs
			{
				
				IniRead,templangcont,%directory%\%templang%.ini,translations,%langvar_no_spaces%,%A_Space%
				;MsgBox %templang% %templangcont%
				if templangcont
					temptlangText:=temptlangText "`n" _language[templang].enlangname ": " templangcont
				
			}
			;~ MsgBox %UILang%
			InputBox,newtrans,% "How is this in " _language[UILang].enlangname "?" ,%langvar_no_spaces% `n%temptlangText%,,% A_ScreenWidth*0.9,% A_ScreenHeight*0.9
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
				iniwrite,% newtrans,%directory%\%UILang%.ini,translations,%langvar_no_spaces%
				if ErrorLevel
				{
					IniDelete,%directory%\%UILang%.ini,translations,%langvar_no_spaces%
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
	else if UsedCache
	{
		_language.cache[langvar_no_spaces]:=initext
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
	global _language
	UILang := _language.UILang
	global langMakeAdditionalCategoryOfTranslationObject
	directory := _language.dir
	
	_language.cache:=Object()
	if langMakeAdditionalCategoryOfTranslationObject
		global langCategoryOfTranslation:=object()
	
	loop,read,%directory%\%UILang%.ini
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
			
			_language.cache[tempItemName]:=tempItemContent
			if langMakeAdditionalCategoryOfTranslationObject
			{
				langCategoryOfTranslation[tempItemName]:=tempCategory
				;~ MsgBox % strobj(langCategoryOfTranslation)
			}
			
			
			
			
		}
		
	}
}