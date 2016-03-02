iniAllActions.="HTTP_Request|" ;Add this action to list of all actions on initialisation

runActionHTTP_Request(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	
	local PostData
	local URL
	
	local Headers:=v_replaceVariables(InstanceID,ThreadID,%ElementID%RequestHeaders)
	if %ElementID%URIEncodeRequestHeaders
		uriencode(Headers)
	
	local Codepage:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Codepage)
	local Contenttype:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Contenttype)
	local Contentlength:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Contentlength)
	local ContentMD5:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ContentMD5)
	local UserAgent:=v_replaceVariables(InstanceID,ThreadID,%ElementID%UserAgent)
	local Flags:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Flags)
	local Proxy:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Proxy)
	local BypassProxy:=v_replaceVariables(InstanceID,ThreadID,%ElementID%BypassProxy)
	local BytesDownloaded
	local Options:=""
	
	if %ElementID%IsExpression=1
		URL:=%ElementID%URL
	else if %ElementID%IsExpression=2
		URL:=v_replaceVariables(InstanceID,ThreadID,%ElementID%URL)
	else if %ElementID%IsExpression=3
		URL:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%URL)
	
	
	
	local ResponseDataVar:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ResponseDataVar)
	if (ResponseDataVar!="" and !v_CheckVariableName(ResponseDataVar) ) 
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Response data variable '" ResponseDataVar "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Response data variable '%1%'",ResponseDataVar)) )
		return
	}
	
	
	local ResponseHeadersVar:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ResponseHeadersVar)
	if (ResponseHeadersVar!="" and !v_CheckVariableName(ResponseHeadersVar) )
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output header '" ResponseHeadersVar "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Output header variable '%1%'",ResponseHeadersVar)) )
		return
	}
	
	if %elementid%WhereToGetPostData=2 ;If data should be sent
	{
		PostData:=v_replaceVariables(InstanceID,ThreadID,%ElementID%PostData)
		if %ElementID%URIEncodePostData
			uriencode(PostData)
		
		if %elementid%WhichCodepage=2
		{
			Options.="Charset: " Codepage "`n"
		}
		else if %elementid%WhichCodepage=3
		{
			Options.="Codepage: " Codepage "`n"
		}
		if %elementid%WhichContentType=2
		{
			Options.="Content-Type: " Contenttype "`n"
		}
		if %elementid%WhichContentLength=2
		{
			Options.="Content-Length: " ContentLength "`n"
		}
		if %elementid%WhichContentMD5=2
		{
			Options.="Content-MD5:"  "`n"
		}
		if %elementid%WhichContentMD5=3
		{
			Options.="Content-MD5: " ContentMD5 "`n"
		}
		
	}
	else if %elementid%WhereToGetPostData=3 ;If file should be used
	{
		local InputFile:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%InputFile)
		if InputFile=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Input file path not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Input file path")))
			return
		}
		if DllCall("Shlwapi.dll\PathIsRelative","Str",InputFile)
			InputFile:=flowSettings.WorkingDir "\" InputFile
		
		Options.="Upload: " InputFile "`n"
	}
	if (%elementid%WhereToGetPostData=2 or %elementid%WhereToGetPostData=3) ;If data or file should be sent
	{
		if %elementid%WhichContentType=2
		{
			Options.="Content-Type: " Contenttype "`n"
		}
		if %elementid%WhichContentLength=2
		{
			Options.="Content-Length: " ContentLength "`n"
		}
		if %elementid%WhichContentMD5=2
		{
			Options.="Content-MD5:"  "`n"
		}
		if %elementid%WhichContentMD5=3
		{
			Options.="Content-MD5: " ContentMD5 "`n"
		}
	}
	if %elementid%WhereToPutResponseData=2 ;If file should be used
	{
		local OutputFile:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%OutputFile)
		if OutputFile=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Output file path not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Output file path")))
			return
		}
		if DllCall("Shlwapi.dll\PathIsRelative","Str",OutputFile)
			OutputFile:=flowSettings.WorkingDir "\" OutputFile
		
		Options.="SaveAs: " OutputFile "`n"
	}
	

	
	
	if %elementid%WhichMethod=2
	{
		Options.="Method: " %elementid%Method "`n"
	}
	if %elementid%WhichUserAgent=2
	{
		Options.="User-Agent: " UserAgent "`n"
	}
	if %elementid%WhichProxy=2
	{
		Options.="AutoProxy" "`n"
	}
	else if %elementid%WhichProxy=3
	{
		Options.="Proxy: " Proxy "`n"
	}
	if %elementid%WhetherBypassProxy=1
	{
		Options.="ProxyBypass: " BypassProxy "`n"
	}
	
	Options.=Flags "`n"
	
	
	
		;~ MsgBox %Options%
	BytesDownloaded := HTTPRequest( URL, PostData, Headers, Options )
	
	v_SetVariable(InstanceID,ThreadID,ResponseDataVar,PostData) ;Variable "VarName" contains a variable name
	v_SetVariable(InstanceID,ThreadID,ResponseHeadersVar,Headers) ;Variable "VarName" contains a variable name
	v_SetVariable(InstanceID,ThreadID,"A_BytesDownloaded",BytesDownloaded,,c_SetBuiltInVar)
	
	
	;~ if ErrorLevel
	;~ {
		;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File not downloaded.")
		;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't download file"))
		;~ return
	;~ }
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionHTTP_Request()
{
	return lang("HTTP_Request") " (" lang("Experimental") ")"
}
getCategoryActionHTTP_Request()
{
	return lang("Internet")
}

getParametersActionHTTP_Request()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("URL")})
	parametersToEdit.push({type: "Radio", id: "IsExpression", default: 1, choices: [lang("This is a Link. It does not contain variables"), lang("This is a Link. It contains variables enclosed in percentage signs"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "URL", default: "http://www.example.com", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Post data")})
	parametersToEdit.push({type: "Radio", id: "WhereToGetPostData", default: 1, choices: [lang("Do not upload any data"), lang("Use follwing post data"), lang("Use file as source (upload)")]})
	parametersToEdit.push({type: "Edit", id: "PostData", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "URIEncodePostData", default: 0, label: lang("URI encode post data")})
	parametersToEdit.push({type: "Label", label: lang("Charset"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "WhichCodepage", default: 1, choices: [lang("Use UTF-8 charset"), lang("Define charset"), lang("Define codepage")]})
	parametersToEdit.push({type: "Edit", id: "Codepage", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "InputFile", label: lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: lang("Request headers")})
	parametersToEdit.push({type: "Edit", id: "RequestHeaders", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "URIEncodeRequestHeaders", default: 0, label: lang("URI encode request headers")})
	
	parametersToEdit.push({type: "Label", label: lang("Response data")})
	parametersToEdit.push({type: "Radio", id: "WhereToPutResponseData", default: 1, choices: [lang("Write response data to a variable"), lang("Write response data to file (download)")]})
	parametersToEdit.push({type: "Label", label: lang("Output variable"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ResponseDataVar", default: "HTTPResponseData", content: "VariableName"})
	;~ parametersToEdit.push({type: "Checkbox", id: "KeepBinary", default: 0, label: langeeee("Don't convert to codepage of AHF. Keep binary instead.")}) ;TODO Binary data
	parametersToEdit.push({type: "Label", label: lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "OutputFile", label: lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: lang("Response headers")})
	parametersToEdit.push({type: "Edit", id: "ResponseHeadersVar", default: "HTTPResponseHeaders", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label: lang("Content type")})
	parametersToEdit.push({type: "Radio", id: "WhichContentType", default: 1, choices: [lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "Edit", id: "Contenttype", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Content length")})
	parametersToEdit.push({type: "Radio", id: "WhichContentLength", default: 1, choices: [lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "Edit", id: "ContentLength", default: "", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Content MD5")})
	parametersToEdit.push({type: "Radio", id: "WhichContentMD5", default: 1, choices: [lang("Do not use"), lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "Edit", id: "ContentMD5", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "WhichMethod", default: 1, choices: [lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "DropDown", id: "Method", default: "GET", choices: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"], result: "name"})
	
	parametersToEdit.push({type: "Label", label: lang("User agent")})
	parametersToEdit.push({type: "Radio", id: "WhichUserAgent", default: 1, choices: [lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "Edit", id: "UserAgent", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Flags")})
	parametersToEdit.push({type: "Edit", id: "Flags", default: "", multiline: true, content: "String"})
	
	parametersToEdit.push({type: "Label", label: lang("Proxy")})
	parametersToEdit.push({type: "Radio", id: "WhichProxy", default: 1, choices: [lang("No proxy"), lang("Automatic"), lang("Custom")]})
	parametersToEdit.push({type: "Edit", id: "Proxy", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Bypass proxy"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "WhetherBypassProxy", default: 0, label: lang("Don't use proxy to access following website")})
	parametersToEdit.push({type: "Edit", id: "BypassProxy", default: "", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

GenerateNameActionHTTP_Request(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("HTTP_Request") " - " GUISettingsOfElement%ID%URL 
	
}

CheckSettingsActionHTTP_Request(ID)
{
	global
	if (GUISettingsOfElement%ID%WhereToGetPostData1 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%PostData
		GuiControl,Disable,GUISettingsOfElement%ID%URIEncodePostData
		GuiControl,Disable,GUISettingsOfElement%ID%InputFile
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage1
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage2
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage3
		GuiControl,Disable,GUISettingsOfElement%ID%Codepage

		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentType1
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentType2
		GuiControl,Disable,GUISettingsOfElement%ID%Contenttype
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentLength1
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentLength2
		GuiControl,Disable,GUISettingsOfElement%ID%ContentLength
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentMD51
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentMD52
		GuiControl,Disable,GUISettingsOfElement%ID%WhichContentMD53
		GuiControl,Disable,GUISettingsOfElement%ID%ContentMD5
	}
	else if (GUISettingsOfElement%ID%WhereToGetPostData2 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%PostData
		GuiControl,Enable,GUISettingsOfElement%ID%URIEncodePostData
		GuiControl,Disable,GUISettingsOfElement%ID%InputFile
		GuiControl,Enable,GUISettingsOfElement%ID%WhichCodepage1
		GuiControl,Enable,GUISettingsOfElement%ID%WhichCodepage2
		GuiControl,Enable,GUISettingsOfElement%ID%WhichCodepage3
		if GUISettingsOfElement%ID%WhichCodepage1=1
			GuiControl,Disable,GUISettingsOfElement%ID%
		else
			GuiControl,Enable,GUISettingsOfElement%ID%

	}
	else if (GUISettingsOfElement%ID%WhereToGetPostData3 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%PostData
		GuiControl,Disable,GUISettingsOfElement%ID%URIEncodePostData
		GuiControl,Enable,GUISettingsOfElement%ID%InputFile
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage1
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage2
		GuiControl,Disable,GUISettingsOfElement%ID%WhichCodepage3
		GuiControl,Disable,GUISettingsOfElement%ID%Codepage

	}
	if (GUISettingsOfElement%ID%WhereToGetPostData2 = 1 or GUISettingsOfElement%ID%WhereToGetPostData3 = 1)
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentType1
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentType2
		
		if GUISettingsOfElement%ID%WhichContentType2=1
			GuiControl,Enable,GUISettingsOfElement%ID%Contenttype
		else
			GuiControl,Disable,GUISettingsOfElement%ID%Contenttype
		
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentLength1
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentLength2
		if GUISettingsOfElement%ID%WhichContentLength2=1
			GuiControl,Enable,GUISettingsOfElement%ID%ContentLength
		else
			GuiControl,Disable,GUISettingsOfElement%ID%ContentLength
		
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentMD51
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentMD52
		GuiControl,Enable,GUISettingsOfElement%ID%WhichContentMD53
		
		if GUISettingsOfElement%ID%WhichContentMD53=1
			GuiControl,Enable,GUISettingsOfElement%ID%ContentMD5
		else
			GuiControl,Disable,GUISettingsOfElement%ID%ContentMD5
		
		
	}
	if GUISettingsOfElement%ID%WhereToPutResponseData1=1
	{
		GuiControl,Enable,GUISettingsOfElement%ID%ResponseDataVar
		GuiControl,Disable,GUISettingsOfElement%ID%OutputFile
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%ResponseDataVar
		GuiControl,Enable,GUISettingsOfElement%ID%OutputFile
	}
	
	if GUISettingsOfElement%ID%WhichMethod2=1
		GuiControl,Enable,GUISettingsOfElement%ID%Method
	else
		GuiControl,Disable,GUISettingsOfElement%ID%Method
	
	if GUISettingsOfElement%ID%WhichUserAgent2=1
		GuiControl,Enable,GUISettingsOfElement%ID%UserAgent
	else
		GuiControl,Disable,GUISettingsOfElement%ID%UserAgent
	
	if GUISettingsOfElement%ID%WhichProxy3=1
		GuiControl,Enable,GUISettingsOfElement%ID%Proxy
	else
		GuiControl,Disable,GUISettingsOfElement%ID%Proxy
	
	if GUISettingsOfElement%ID%WhichProxy1=1
	{
		GuiControl,Disable,GUISettingsOfElement%ID%WhetherBypassProxy
		GuiControl,Disable,GUISettingsOfElement%ID%BypassProxy
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%WhetherBypassProxy
		if GUISettingsOfElement%ID%WhetherBypassProxy=1
			GuiControl,Enable,GUISettingsOfElement%ID%BypassProxy
		else
			GuiControl,Disable,GUISettingsOfElement%ID%BypassProxy
	}
	
}
