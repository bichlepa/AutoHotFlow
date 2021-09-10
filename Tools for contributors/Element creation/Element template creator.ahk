#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance, force

FileRead,template, *t raw templates\template - action.ahk

;get root AHF path
ahf_path := a_scriptDir
Loop
{
	ahf_pathOld := ahf_path
	ahf_path := substr(ahf_path,1, instr(ahf_path, "\", ,0) - 1)
	if (ahf_pathOld = ahf_path)
	{
		MsgBox, Error. Cant find root folder of AHF
		ExitApp
	}
	if fileexist(ahf_path "\AutoHotFlow.ahk")
		break
}

; find all packages
allPackages := "Default"
loop, files, %ahf_path%\Source_elements\*, D
{
	if (A_LoopFileName = "Default")
		continue
	allPackages .= "|"
	allPackages .= A_LoopFileName
}



;build GUI
guih:=a_screenheight*0.9
posx1:="xs"
posx2:="xs+150"

gui,add,edit,xm ym w800 h%guih% vGeneratedCode readonly
gui,add,text,yp section X+20, Options
gui,add,text,%posx1% Y+20, Package
gui,add,dropdownlist,yp %posx2% vElementPackage choose1 gpackageSelect, %allPackages%
gui,add,text,%posx1% Y+20, Element type
gui,add,dropdownlist,yp %posx2% vElementType choose1 gElementTypeSelect, Action|Condition|Loop|Trigger
gui,add,text,%posx1% Y+20, Name
gui,add,edit,yp %posx2% vName ggenerate w100 +hwndhwndName, MyName
gui,add,text,%posx1% Y+20, Category
gui,add,ComboBox,yp %posx2% vCategory choose1 ggenerate
gui,add,text,%posx1% Y+20, Experience level
gui,add,dropdownlist,yp %posx2% vExperienceLevel choose1 ggenerate, % "Beginner|Advanced|Programmer"
gui,add,text,%posx1% Y+20, Icon
gui,add,dropdownlist,yp %posx2% vIcon choose1 ggenerate, % allicons
gui,add,text,%posx1% Y+20, Stability
gui,add,dropdownlist,yp %posx2% vstability choose1 ggenerate, % "Stable|Experimental"

gui,add,text,%posx1% Y+20, Editor GUI contents
gui,add,checkbox,yp %posx2% vpar_label ggenerate checked, Label
gui,add,checkbox,Y+10 %posx2% vpar_checkbox ggenerate checked, Checkbox
gui,add,checkbox,Y+10 %posx2% vpar_radio ggenerate, Radio (Number)
gui,add,checkbox,Y+10 %posx2% vpar_radioEnum ggenerate, Radio (Enum)
gui,add,checkbox,Y+10 %posx2% vpar_editString ggenerate, Edit (string)
gui,add,checkbox,Y+10 %posx2% vpar_editExpression ggenerate, Edit (expression)
gui,add,checkbox,Y+10 %posx2% vpar_editStringOrExpression ggenerate, Edit (string or expression)
gui,add,checkbox,Y+10 %posx2% vpar_editVariableName ggenerate, Edit (variable name)
gui,add,checkbox,Y+10 %posx2% vpar_editMultiLine ggenerate, Edit (multiline)
gui,add,checkbox,Y+10 %posx2% vpar_editTwoExpressions ggenerate, Edit (two expressions)
gui,add,checkbox,Y+10 %posx2% vpar_DropDownString ggenerate, DropDown (string)
gui,add,checkbox,Y+10 %posx2% vpar_ComboBoxString ggenerate, ComboBox (string)
gui,add,checkbox,Y+10 %posx2% vpar_ListBoxString ggenerate, ListBox (string)
gui,add,checkbox,Y+10 %posx2% vpar_Slider ggenerate, Slider
gui,add,checkbox,Y+10 %posx2% vpar_file ggenerate, File
gui,add,checkbox,Y+10 %posx2% vpar_folder ggenerate, Folder
gui,add,checkbox,Y+10 %posx2% vpar_button ggenerate, Button
gui,add,checkbox,Y+20 %posx2% vcustomParameterEvaluation ggenerate, Custom parameter evaluation

gui,add,text,%posx1% Y+20, Pre-coded features
gui,add,radio,yp %posx2% vaddNothing ggenerate checked, None
gui,add,radio,Y+10 %posx2% vaddWindowSelector ggenerate, Add window selector
gui,add,radio,Y+10 %posx2% vaddSeparateAhkThread ggenerate, Execute in separate ahk thread
gui,add,radio,Y+10 %posx2% vaddCustomGUI ggenerate, Add custom GUI

gui,add,button,Y+30 %posx1% gReloadTemplate, Reload template
gui,add,button,yp %posx2% gExport, Generate file

gui,show
packageSelect()
ElementTypeSelect()
generate()
return

packageSelect()
{
	global

	gui, submit, nohide

	;Find all available icons
	allicons:="|"
	loop,files,%ahf_path%\Source_elements\%ElementPackage%\Icons\*
	{
		if a_index != 1
			allicons .= "|"
		allicons.= "" A_LoopFileName
		
	}
	
	guicontrol,, Icon, % allicons
	ElementTypeSelect()
	generate()
}

ElementTypeSelect()
{
	
	global

	gui, submit, nohide

	;Find all available icons
	allcategories:="|"
	loop,files,%ahf_path%\Source_elements\%ElementPackage%\%ElementType%s\*.ahk
	{
		fileread, filecategory, % A_LoopFileFullPath
		filecategory := substr(filecategory, instr(filecategory, "Element_getCategory"))
		filecategory := substr(filecategory, instr(filecategory, "return"))
		filecategory := substr(filecategory, instr(filecategory, """") + 1)
		filecategory := substr(filecategory, 1, instr(filecategory, """") - 1)

		if not instr(allcategories, "|" filecategory "|")
			allcategories .= filecategory "|"
	}
	
	guicontrol,, category, % allcategories
	guicontrol,choose, category, % Category
	ReloadTemplate()
	generate()
}

ReloadTemplate()
{
	global
	gui, submit, nohide
	FileRead,template, *t raw templates\template - %ElementType%.ahk
	generate()
}

generate()
{
	global
		
	gui,submit,nohide

	; check and correct name
	if instr(Name, " ")
	{
		Name := StrReplace(Name, " " , "_")
		guicontrol,, Name, %Name%
		controlsend,,{end}, % "ahk_ID " hwndName
	}

	mode:="grab"
	skipLevel:=0
	tree:=""
	generatedCode:=""
	loop,parse,template,`n
	{
		oneline:=a_loopfield
		onelineTrimmed:=trim(a_loopfield)
		
		IfInString,onelineTrimmed,#if
		{
			expression:=trim(substr(onelinetrimmed,instr(onelineTrimmed,"#if") + strlen("#if")))
			if (evalExpression(expression))
			{
				tree.="1"
			}
			else
			{
				tree.="0"
			}
			;~ MsgBox #if in line %a_index%. Tree: %tree%
		}
		else IfInString,onelineTrimmed,#endif
		{
			StringTrimRight,tree,tree,1
			;~ MsgBox #endif in line %a_index%. Tree: %tree%
		}
		else IfInString,onelineTrimmed,#else
		{
			StringRight,oneTreeItem,tree,1
			StringTrimRight,tree,tree,1
			tree.=!oneTreeItem
			;~ MsgBox #else in line %a_index%. Tree: %tree%
		}
		else
		{
			IfNotInString,tree,0
				generatedCode.=oneline "`n"
		}
			
		
	}

	StringReplace, generatedCode,generatedCode,&elementtype&,%elementtype%,a
	StringReplace, generatedCode,generatedCode,&Name&,%Name%,a
	StringReplace, generatedCode,generatedCode,&Category&,%Category%,a
	StringReplace, generatedCode,generatedCode,&package&,%ElementPackage%,a
	StringReplace, generatedCode,generatedCode,&stability&,%stability%,a
	StringReplace, generatedCode,generatedCode,&Level&,%ExperienceLevel%,a
	guicontrol,,generatedCode,%generatedCode%
}

export()
{
	global

	gui, submit, nohide
	if (name = "")
	{
		MsgBox, name is empty.
		return
	}
	if (category = "")
	{
		MsgBox, category is empty.
		return
	}

	elementFolderPath = %ahf_path%\Source_elements\%ElementPackage%\%ElementType%s
	elementFilePath = %elementFolderPath%\%name%.ahk
	if fileexist(elementFilePath)
	{
		MsgBox, file already exists.
		return
	}
	FileAppend, % generatedCode, % elementFilePath
	run, % elementFolderPath
}

evalExpression(expression)
{
	global
	local result:=false
	local varname
	local negated:=false
	;~ MsgBox %expression%
	IfInString,expression,=
	{
		loop,parse,expression,=
		{
			if a_index = 1
			{
				if (substr(expression,1,1)="!")
				{
					varname:=trim(substr(a_loopfield,2))
					negated:=true
				}
				else
				{
					varname:=trim(a_loopfield)
				}
			}
			if a_index = 2
			{
				if varname
				{
					;~ MsgBox % %varname%  " == " a_loopfield
					loop,parse,a_loopfield,|
					{
						varvalue:=trim(a_loopfield)
						;~ MsgBox % "'" %varname% "'" " = " "'" varvalue "'"
						if (%varname% = varvalue)
						{
							result:=true
						}
					}
				}
			}
		}
	}
	else
	{
		if (substr(expression,1,1)="!")
		{
			varname:=trim(substr(expression,2))
			if not (%varname%)
				result:=True
			
		}
		else
		{
			varname:=expression
			if (%varname%)
				result:=True
		}
	}
	;~ MsgBox expression result: %result%
	if negated
		result := not result
	return result
}

guiclose()
{
	ExitApp
}

