iniAllActions.="Traytip|" ;Add this action to list of all actions on initialisation

class ActionTraytip extends ElementExecution
{
	__new(p_Thread)
	{
		;~ MsgBox awg
		base.__new(p_Thread)
	}
	
	run()
	{
		;~ MsgBox run!!!
		global flowSettings
		base.run()
		;~ d(this)
		temptext:=variable.replaceVariables(this.thread,this.element.par.text)
		tempTitle:=variable.replaceVariables(this.thread,this.element.par.Title)
		tempIcon:=this.thread,this.par.Icon
		
		if tempTitle=
			tempTitle:=flowSettings.Name
		
		Traytip,%tempTitle%,%temptext%,,% tempIcon -1
		
		this.end("normal")
		;~ MsgBox seaihjioehfioö
	}
	
	getname()
	{
		return lang("Traytip")
	}
	getCategory()
	{
		return lang("User_interaction")
	}
	getParameters()
	{
		global
		parametersToEdit:=Object()
		parametersToEdit.push({type: "Label", label: lang("Title")})
		parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String"})
		parametersToEdit.push({type: "Label", label: lang("Text_to_show")})
		parametersToEdit.push({type: "Edit", id: "text", default: lang("Message"), multiline: true, content: "String"})
		parametersToEdit.push({type: "Label", label: lang("Icon")})
		parametersToEdit.push({type: "Radio", id: "Icon", default: 1, choices: [lang("No icon"), lang("Info icon"), lang("Warning icon"), lang("Error icon")]})

	return parametersToEdit

	}
	
	generateName()
	{
		global
		;MsgBox % %ID%text_to_show

		return lang("Traytip") ": " ElementSettingsFieldParIDs["title"].getvalue() "`n" ElementSettingsFieldParIDs["text"].getvalue()
	
	}
}
