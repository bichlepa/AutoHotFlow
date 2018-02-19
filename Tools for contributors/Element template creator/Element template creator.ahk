#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

FileRead,template, *t raw templates\template.ahk

;Find all available icons

StringReplace,ahf_path,a_scriptDir,\Tools for contributors\Element template creator
allicons:=""
loop,files,%ahf_path%\Source_elements\Icons,DR
{
	loop,files,%A_LoopFileFullPath%\*.*,F
	{
		allicons.= "|" A_LoopFileName
	}
}
;build GUI
guih:=a_screenheight*0.9
posx1:="xs"
posx2:="xs+150"

gui,add,edit,xm ym w800 h%guih% vGeneratedCode readonly
gui,add,text,yp section X+20, Options
gui,add,text,%posx1% Y+20, Element type
gui,add,dropdownlist,yp %posx2% vElementType choose1 ggenerate, Action|Condition|Loop|Trigger
gui,add,text,%posx1% Y+20, Name
gui,add,edit,yp %posx2% vName ggenerate w100, MyName
gui,add,text,%posx1% Y+20, Category
gui,add,dropdownlist,yp %posx2% vCategory choose1 ggenerate, Variable|Flow_control|Window|Sound|Image|File|Drive|User_interaction|User_simulation|Time|Power|Process|Internet|Debugging|Expert
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

gui,add,text,%posx1% Y+20, Pre-coded features
gui,add,checkbox,yp %posx2% vcustomParameterEvaluation ggenerate, Custom parameter evaluation
gui,add,checkbox,Y+10 %posx2% vaddWindowSelector ggenerate, Add window selector
gui,add,checkbox,Y+10 %posx2% vaddSeparateAhkThread ggenerate, Execute in separate ahk thread
gui,add,checkbox,Y+10 %posx2% vaddCustomGUI ggenerate, Add custom GUI

gui,add,button,Y+30 %posx1% gReloadTemplate, Reload template

gui,show
gosub,generate
return

ReloadTemplate()
{
	global
	FileRead,template, *t raw templates\template.ahk
	gosub generate
}

generate:
gui,submit,nohide

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
StringReplace, generatedCode,generatedCode,&Category&,%Category%,a
StringReplace, generatedCode,generatedCode,&stability&,%stability%,a
guicontrol,,generatedCode,%generatedCode%

return

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