iniAllActions.="New_variable|" ;Add this action to list of all actions on initialisation

class ActionNew_variable extends ElementExecution
{
	__new(p_Thread)
	{
		base.__new(p_Thread)
	}
	
	run()
	{
		base.run()
		Varname:=variable.replaceVariables(this.thread,this.element.par.VarName)
		if not variable.NameIsValid(varname)
		{
			logger("f0","Instance " this.Instance.ID " - " this.Element.type " '" this.element.name "': Error! Ouput variable name '" varname "' is not valid")
			this.end("exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
			return
		}
		
		if (this.par.expression=2)
		{
			;~ Value:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%VarValue)
			Value:=variable.EvaluateExpression(this.thread,this.element.par.VarValue)
		}
		else
		{
			;~ Value:=this.thread.replaceVariables(this.par.VarValue)
			Value:=variable.replaceVariables(this.thread,this.element.par.VarValue) 
		}
		
		variable.set(this.thread,Varname,Value)
		
		this.end("normal")
		
	}
	
	getname()
	{
		return lang("New_variable")
	}
	getCategory()
	{
		return lang("Variable")
	}
	getParameters()
	{
		global
		parametersToEdit:=Object()
		parametersToEdit.push({type: "Label", label: lang("Variable_name")})
		parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
		parametersToEdit.push({type: "Label", label:  lang("Value")})
		;~ parametersToEdit.push({type: "Radio", id: "expression", default: 1, choices: [lang("This is a value"), lang("This is a variable name or expression")]})
		parametersToEdit.push({type: "Edit", id: ["VarValue","expression"], default: ["New element",1], content: "StringOrExpression", contentParID: "expression", WarnIfEmpty: true})

		return parametersToEdit

	}
	
	generateName()
	{
		global
		local temp
		;~ ToolTip updatename 
		;~ MsgBox % ElementSettingsFieldParIDs["Varname"].getvalue() " - " ElementSettingsFieldParIDs["VarValue"].getvalue()   "`n`n" strobj(ElementSettingsFieldParIDs["Varname"]) 
		temp:=lang("New_variable") "`n" ElementSettingsFieldParIDs["Varname"].getvalue() " = " ElementSettingsFieldParIDs["VarValue"].getvalue()  
		return temp
	}
}
