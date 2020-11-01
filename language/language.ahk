
/*
lang() by bichlepa
license: GPL v3


contents of _language:
	;Settings:
	.lang			the two character language code of the desired language (eg. "en" or "de") (default: automatic then "en")
	.fallbacklang	fallback language if a translation is not available in the desired language (default: "en")
	.dir			path to the translation files (default: A_ScriptDir "\language")
	.readAll		If true, it will read all translations into cache on initialization. Recommended. FAST! (default: false)
	.noCache		If true, no cache will be used. On every call of lang() the ini file will be accessed. Not recommended. SLOW! (default: false)
	
	;Informations:
	.allLangs		associative array of objects with informations about the available languages. The keys are the language codes
		.code			the two character long code of the desired language
		.langname		language name
		.enlangname		language name in English
		.filepath		filepath of the translation file
	.langindex		language index of the desired language. Can be used in following arrays
	.allLangCodes	Array of strings with all available language codes
	.allLangNames	Array of strings with all available language names
	.allLangEnNames	Array of strings with all available language names in English
	.success		Is set after a call of lang(). 1 if a translation was found in desired language, 0 if found in fallback language, -1 if not found at all.
	
	;other values are for internal use

*/

;Initialization. Find all available languages and set the current language
lang_init()
{
	global _language
	if not isobject(_language)
		_language:=Object()
	directory := _language.dir
	
	;set defeault settings
	if (not directory)
		directory:= A_ScriptDir "\language"
	_language.dir:=directory
	if (not _language.fallbacklang)
		_language.fallbacklang:="en"
	
	_language.allLangs:=Object()
	_language.allLangCodes:=Object()
	_language.allLangNames:=Object()
	_language.allLangEnNames:=Object()
	
	;Search for languages
	Loop,%directory%\*.ini
	{
		StringReplace,code,A_LoopFileName,.%A_LoopFileExt%
		
		IniRead,enlangname,%A_LoopFileFullPath%,language_info,enname
		IniRead,langname,%A_LoopFileFullPath%,language_info,name
		
		if (enlangname != "Error" && langname != "Error" && code != "Error")
		{
			_language.allLangs[code] := Object()
			_language.allLangs[code].enlangname := enlangname
			_language.allLangs[code].langname := langname
			_language.allLangs[code].code := code
			_language.allLangs[code].filepath := A_LoopFileFullPath
			_language.allLangCodes.push(code)
			_language.allLangNames.push(langname)
			_language.allLangEnNames.push(enlangname)
		}
	}

	_language.lang_init_called:=true
	
	initLanguageCodes()
}

;Set a language. It can be called to change the language. You can either pass the code, Name, EnName or the index of the language
lang_setLanguage(p_lang = "")
{
	global _language
	
	if (not _language.lang_init_called)
	{
		MsgBox,16, bug!, lang_setLanguage() must becalled before lang_init()
		return
	}
	
	if (p_lang != "")
	{
		if p_lang is number
			lang:=_language.allLangCodes[p_lang]
		else
		{
			for onecode, onelang in _language.allLangs
			{
				if (onecode = p_lang)
				{
					lang:= onecode
					break
				}
				if (onelang.enlangname = p_lang)
				{
					lang:= onecode
					break
				}
				if (onelang.langname = p_lang)
				{
					lang:= onecode
					break
				}
			}
		}
		
		if (not lang)
		{
			MsgBox, 16, , Language "%p_lang%" is invalid.
			return
		}
	}
	
	_language.lang := lang
	_language.cache := Object() ;Delete cache
	directory := _language.dir
	
	;if no language was set, try to automatically detect the proper language
	if (not lang)
	{
		syslang:=_language.systemcodes["" A_Language]
		for onecode, onelang in _language.allLangs
		{
			templangenname:=onelang.langenname
			templangcode:=onelang.code
			IfInString, syslang, %templangenname%
			{
				_language.lang := templangcode
				break
			}
		}
		;if no language found, set english as default
		if (not _language.lang)
		{
			_language.lang:="en"
		}
	}
	
	if (_language.readAll)
		lang_ReadAllTranslations()
	
	_language.lang_setLanguage_called:=true
}

;translate one string
lang(langvar, langReplacements*)
{
	global _language, developing
	
	if (not _language.lang_init_called)
	{
		MsgBox,16, bug!, lang_setLanguage() must becalled before lang()
		return
	}
	
	;if set language was not called yet, call it now
	if (not _language.lang_setLanguage_called)
	{
		lang_setLanguage(_language.lang)
	}
	
	lang := _language.lang
	NoCache := _language.NoCache
	directory := _language.dir
	filepath := _language.allLangs[lang].filepath
	fallbackfilepath := _language.allLangs[_language.fallbacklang].filepath
	
	if (langvar ="")
		return ""
	if not isobject(_language.cache)
		_language.cache:=Object()
	
	langaborted:=false
	StringReplace,langvar,langvar,_,%a_space%,all
	
	langBeginAgain:
	;look whether the string is in cache
	if ((!(NoCache)) and (_language.cache.haskey(langvar)))
	{
		initext:=_language.cache[langvar]
		UsedCache:=true
		if initext
		{
			_language.success:=1
		}
	}
	;if the translation was not in cache or empty or the cache should not be used
	if (initext="")
	{
		;read from ini file
		IniRead,iniAllSections,%filepath%
		Loop,parse,iniAllSections,`n
		{
			IniRead,initext,%filepath%,%a_loopfield%,%langvar%,%A_Space%
			if initext
			{
				_language.success:=1
				break
			}
		}
		
		UsedCache:=false
	}
	
	;if the translation was not found in the ini file of desired language, use fallback language
	if (initext="")
	{
		IniRead,iniAllSections,%fallbackfilepath%
		Loop,parse,iniAllSections,`n
		{
			IniRead,initext,%fallbackfilepath%,%a_loopfield%,%langvar%,%A_Space%
			if initext
			{
				_language.success:=0
				break
			}
		}
		
		;~ MsgBox %initexten%, %langvar%
		if (initext="") 
		{
			;If no translation was found, just insert the raw text
			_language.success:=-1
			initext := langvar
		}
	}
	else if (not NoCache)
	{
		;save the translation in cache
		_language.cache[langvar]:=initext
	}
	
	;Replace
	for oneIndex, oneReplacement in langReplacements
	{
		StringReplace, initext, initext,% "%" a_index "%", % oneReplacement, all
	}
	
	
	return initext
	
}

;Can be called to read all translations of one language. This will increase the speed on later calls
lang_ReadAllTranslations()
{
	global _language
	lang := _language.lang
	directory := _language.dir
	filepath := _language.allLangs[lang].filepath
	
	_language.cache := Object()
	
	;this is needed for the script "Search for new strings to translate"
	if (_language.MakeAdditionalCategoryOfTranslationObject)
		global langCategoryOfTranslation := object()
	
	loop,read,%filepath%
	{
		
		ifinstring,a_loopreadline,[
			ifinstring,a_loopreadline,]
			{
				tempCategory:=trim(a_loopreadline) ;Remove spaces (if any)
				tempCategory:=trim(a_loopreadline,"[]") ;remove brackets
			}
		
		if tempCategory=language_info
			continue
		
		;add translation to cache
		ifinstring,a_loopreadline,=
		{
			stringgetpos,pos,a_loopreadline,=
			stringleft,tempItemName,a_loopreadline,%pos%
			
			StringTrimLeft,tempItemContent,a_loopreadline,% (pos +1)
			
			_language.cache[tempItemName]:=tempItemContent
			
			;this is needed for the script "Search for new strings to translate"
			if (_language.MakeAdditionalCategoryOfTranslationObject)
			{
				langCategoryOfTranslation[tempItemName]:=tempCategory
			}
		}
	}
}

initLanguageCodes()
{
	global _language
	_language.systemcodes:=object()
	_language.systemcodes["0436"] := "Afrikaans"
	_language.systemcodes["041c"] := "Albanian"
	_language.systemcodes["0401"] := "Arabic_Saudi_Arabia"
	_language.systemcodes["0801"] := "Arabic_Iraq"
	_language.systemcodes["0c01"] := "Arabic_Egypt"
	_language.systemcodes["0401"] := "Arabic_Saudi_Arabia"
	_language.systemcodes["0801"] := "Arabic_Iraq"
	_language.systemcodes["0c01"] := "Arabic_Egypt"
	_language.systemcodes["1001"] := "Arabic_Libya"
	_language.systemcodes["1401"] := "Arabic_Algeria"
	_language.systemcodes["1801"] := "Arabic_Morocco"
	_language.systemcodes["1c01"] := "Arabic_Tunisia"
	_language.systemcodes["2001"] := "Arabic_Oman"
	_language.systemcodes["2401"] := "Arabic_Yemen"
	_language.systemcodes["2801"] := "Arabic_Syria"
	_language.systemcodes["2c01"] := "Arabic_Jordan"
	_language.systemcodes["3001"] := "Arabic_Lebanon"
	_language.systemcodes["3401"] := "Arabic_Kuwait"
	_language.systemcodes["3801"] := "Arabic_UAE"
	_language.systemcodes["3c01"] := "Arabic_Bahrain"
	_language.systemcodes["4001"] := "Arabic_Qatar"
	_language.systemcodes["042b"] := "Armenian"
	_language.systemcodes["042c"] := "Azeri_Latin"
	_language.systemcodes["082c"] := "Azeri_Cyrillic"
	_language.systemcodes["042d"] := "Basque"
	_language.systemcodes["0423"] := "Belarusian"
	_language.systemcodes["0402"] := "Bulgarian"
	_language.systemcodes["0403"] := "Catalan"
	_language.systemcodes["0404"] := "Chinese_Taiwan"
	_language.systemcodes["0804"] := "Chinese_PRC"
	_language.systemcodes["0c04"] := "Chinese_Hong_Kong"
	_language.systemcodes["1004"] := "Chinese_Singapore"
	_language.systemcodes["1404"] := "Chinese_Macau"
	_language.systemcodes["041a"] := "Croatian"
	_language.systemcodes["0405"] := "Czech"
	_language.systemcodes["0406"] := "Danish"
	_language.systemcodes["0413"] := "Dutch_Standard"
	_language.systemcodes["0813"] := "Dutch_Belgian"
	_language.systemcodes["0409"] := "English_United_States"
	_language.systemcodes["0809"] := "English_United_Kingdom"
	_language.systemcodes["0c09"] := "English_Australian"
	_language.systemcodes["1009"] := "English_Canadian"
	_language.systemcodes["1409"] := "English_New_Zealand"
	_language.systemcodes["1809"] := "English_Irish"
	_language.systemcodes["1c09"] := "English_South_Africa"
	_language.systemcodes["2009"] := "English_Jamaica"
	_language.systemcodes["2409"] := "English_Caribbean"
	_language.systemcodes["2809"] := "English_Belize"
	_language.systemcodes["2c09"] := "English_Trinidad"
	_language.systemcodes["3009"] := "English_Zimbabwe"
	_language.systemcodes["3409"] := "English_Philippines"
	_language.systemcodes["0425"] := "Estonian"
	_language.systemcodes["0438"] := "Faeroese"
	_language.systemcodes["0429"] := "Farsi"
	_language.systemcodes["040b"] := "Finnish"
	_language.systemcodes["040c"] := "French_Standard"
	_language.systemcodes["080c"] := "French_Belgian"
	_language.systemcodes["0c0c"] := "French_Canadian"
	_language.systemcodes["100c"] := "French_Swiss"
	_language.systemcodes["140c"] := "French_Luxembourg"
	_language.systemcodes["180c"] := "French_Monaco"
	_language.systemcodes["0437"] := "Georgian"
	_language.systemcodes["0407"] := "German_Standard"
	_language.systemcodes["0807"] := "German_Swiss"
	_language.systemcodes["0c07"] := "German_Austrian"
	_language.systemcodes["1007"] := "German_Luxembourg"
	_language.systemcodes["1407"] := "German_Liechtenstein"
	_language.systemcodes["0408"] := "Greek"
	_language.systemcodes["040d"] := "Hebrew"
	_language.systemcodes["0439"] := "Hindi"
	_language.systemcodes["040e"] := "Hungarian"
	_language.systemcodes["040f"] := "Icelandic"
	_language.systemcodes["0421"] := "Indonesian"
	_language.systemcodes["0410"] := "Italian_Standard"
	_language.systemcodes["0810"] := "Italian_Swiss"
	_language.systemcodes["0411"] := "Japanese"
	_language.systemcodes["043f"] := "Kazakh"
	_language.systemcodes["0457"] := "Konkani"
	_language.systemcodes["0412"] := "Korean"
	_language.systemcodes["0426"] := "Latvian"
	_language.systemcodes["0427"] := "Lithuanian"
	_language.systemcodes["042f"] := "Macedonian"
	_language.systemcodes["043e"] := "Malay_Malaysia"
	_language.systemcodes["083e"] := "Malay_Brunei_Darussalam"
	_language.systemcodes["044e"] := "Marathi"
	_language.systemcodes["0414"] := "Norwegian_Bokmal"
	_language.systemcodes["0814"] := "Norwegian_Nynorsk"
	_language.systemcodes["0415"] := "Polish"
	_language.systemcodes["0416"] := "Portuguese_Brazilian"
	_language.systemcodes["0816"] := "Portuguese_Standard"
	_language.systemcodes["0418"] := "Romanian"
	_language.systemcodes["0419"] := "Russian"
	_language.systemcodes["044f"] := "Sanskrit"
	_language.systemcodes["081a"] := "Serbian_Latin"
	_language.systemcodes["0c1a"] := "Serbian_Cyrillic"
	_language.systemcodes["041b"] := "Slovak"
	_language.systemcodes["0424"] := "Slovenian"
	_language.systemcodes["040a"] := "Spanish_Traditional_Sort"
	_language.systemcodes["080a"] := "Spanish_Mexican"
	_language.systemcodes["0c0a"] := "Spanish_Modern_Sort"
	_language.systemcodes["100a"] := "Spanish_Guatemala"
	_language.systemcodes["140a"] := "Spanish_Costa_Rica"
	_language.systemcodes["180a"] := "Spanish_Panama"
	_language.systemcodes["1c0a"] := "Spanish_Dominican_Republic"
	_language.systemcodes["200a"] := "Spanish_Venezuela"
	_language.systemcodes["240a"] := "Spanish_Colombia"
	_language.systemcodes["280a"] := "Spanish_Peru"
	_language.systemcodes["2c0a"] := "Spanish_Argentina"
	_language.systemcodes["300a"] := "Spanish_Ecuador"
	_language.systemcodes["340a"] := "Spanish_Chile"
	_language.systemcodes["380a"] := "Spanish_Uruguay"
	_language.systemcodes["3c0a"] := "Spanish_Paraguay"
	_language.systemcodes["400a"] := "Spanish_Bolivia"
	_language.systemcodes["440a"] := "Spanish_El_Salvador"
	_language.systemcodes["480a"] := "Spanish_Honduras"
	_language.systemcodes["4c0a"] := "Spanish_Nicaragua"
	_language.systemcodes["500a"] := "Spanish_Puerto_Rico"
	_language.systemcodes["0441"] := "Swahili"
	_language.systemcodes["041d"] := "Swedish"
	_language.systemcodes["081d"] := "Swedish_Finland"
	_language.systemcodes["0449"] := "Tamil"
	_language.systemcodes["0444"] := "Tatar"
	_language.systemcodes["041e"] := "Thai"
	_language.systemcodes["041f"] := "Turkish"
	_language.systemcodes["0422"] := "Ukrainian"
	_language.systemcodes["0420"] := "Urdu"
	_language.systemcodes["0443"] := "Uzbek_Latin"
	_language.systemcodes["0843"] := "Uzbek_Cyrillic"
	_language.systemcodes["042a"] := "Vietnamese"
}

