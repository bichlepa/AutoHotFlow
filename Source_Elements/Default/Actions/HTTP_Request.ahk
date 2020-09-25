;Always add this element class name to the global list
x_RegisterElementClass("Action_HTTP_Request")

;Element type of the element
Element_getElementType_Action_HTTP_Request()
{
	return "Action"
}

;Name of the element
Element_getName_Action_HTTP_Request()
{
	return lang("HTTP_Request")
}

;Category of the element
Element_getCategory_Action_HTTP_Request()
{
	return lang("Internet")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_HTTP_Request()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_HTTP_Request()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_HTTP_Request()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_HTTP_Request()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_HTTP_Request(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("URL")})
	parametersToEdit.push({type: "Edit", id: "URL", default: "http://www.example.com", content: ["RawString", "String", "Expression"], contentID: "IsExpression", contentDefault: "string", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Post data")})
	parametersToEdit.push({type: "Radio", id: "WhereToGetPostData", default: 1, result: "Enum", choices: [lang("Do not upload any data"), lang("Use follwing post data"), lang("Use file as source (upload)")], enum: ["NoUpload", "Specified", "File"]})
	parametersToEdit.push({type: "Edit", id: "PostData", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "URIEncodePostData", default: 0, label: lang("URI encode post data")})
	parametersToEdit.push({type: "Label", label: lang("Charset"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "WhichCodepage", default: 1, result: "Enum", choices: [lang("Use UTF-8 charset"), lang("Define charset"), lang("Define codepage")], enum: ["utf-8", "definedCharset", "definedCodepage"]})
	parametersToEdit.push({type: "Edit", id: "Codepage", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "InputFile", label: lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: lang("Request headers")})
	parametersToEdit.push({type: "Edit", id: "RequestHeaders", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "URIEncodeRequestHeaders", default: 0, label: lang("URI encode request headers")})
	
	parametersToEdit.push({type: "Label", label: lang("Response data")})
	parametersToEdit.push({type: "Radio", id: "WhereToPutResponseData", default: 1, result: "Enum", choices: [lang("Write response data to a variable"), lang("Write response data to file (download)")], enum: ["Variable", "File"]})
	parametersToEdit.push({type: "Label", label: lang("Output variable"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ResponseDataVar", default: "HTTPResponseData", content: "VariableName"})
	;~ parametersToEdit.push({type: "Checkbox", id: "KeepBinary", default: 0, label: langeeee("Don't convert to codepage of AHF. Keep binary instead.")}) ;TODO Binary data
	parametersToEdit.push({type: "Label", label: lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "OutputFile", default: "HTTPResponseData.html", label: lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: lang("Response headers")})
	parametersToEdit.push({type: "Edit", id: "ResponseHeadersVar", default: "HTTPResponseHeaders", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label: lang("Content type")})
	parametersToEdit.push({type: "Radio", id: "WhichContentType", default: 1, result: "Enum", choices: [lang("Automatic"), lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "Contenttype", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Content length")})
	parametersToEdit.push({type: "Radio", id: "WhichContentLength", default: 1, result: "Enum", choices: [lang("Automatic"), lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "ContentLength", default: "", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Content MD5")})
	parametersToEdit.push({type: "Radio", id: "WhichContentMD5", default: 1, result: "Enum", choices: [lang("Do not use"), lang("Automatic"), lang("Custom")], enum: ["none", "automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "ContentMD5", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "WhichMethod", default: 1, result: "Enum", choices: [lang("Automatic"), lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "DropDown", id: "Method", default: "GET", result: "enum", choices: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"], enum: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"]})
	
	parametersToEdit.push({type: "Label", label: lang("User agent")})
	parametersToEdit.push({type: "Radio", id: "WhichUserAgent", default: 1, result: "Enum", choices: [lang("Automatic"), lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "UserAgent", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Flags")})
	parametersToEdit.push({type: "Edit", id: "Flags", default: "", multiline: true, content: "String"})
	
	parametersToEdit.push({type: "Label", label: lang("Proxy")})
	parametersToEdit.push({type: "Radio", id: "WhichProxy", default: 1, result: "Enum", choices: [lang("No proxy"), lang("Automatic"), lang("Custom")], enum: ["none", "automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "Proxy", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Bypass proxy"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "WhetherBypassProxy", default: 0, label: lang("Don't use proxy to access following website")})
	parametersToEdit.push({type: "Edit", id: "BypassProxy", default: "", content: "String", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_HTTP_Request(Environment, ElementParameters)
{
	return lang("HTTP_Request") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_HTTP_Request(Environment, ElementParameters)
{	
	if (ElementParameters.WhereToGetPostData = "NoUpload")
	{
		x_Par_Disable("PostData")
		x_Par_Disable("URIEncodePostData")
		x_Par_Disable("InputFile")
		x_Par_Disable("WhichCodepage")
		x_Par_Disable("Codepage")
		x_Par_Disable("WhichContentType")
		x_Par_Disable("Contenttype")
		x_Par_Disable("WhichContentLength")
		x_Par_Disable("ContentLength")
		x_Par_Disable("WhichContentMD5")
		x_Par_Disable("ContentMD5")
	}
	else 
	{
		x_Par_Enable("WhichContentType")
		
		if (ElementParameters.WhichContentType="automatic")
			x_Par_Enable("Contenttype")
		else
			x_Par_Disable("Contenttype")
		
		x_Par_Enable("WhichContentLength")
		if (ElementParameters.WhichContentLength="automatic")
			x_Par_Enable("ContentLength")
		else
			x_Par_Disable("ContentLength")
		
		x_Par_Enable("WhichContentMD5")
		if (ElementParameters.WhichContentLength="automatic")
			x_Par_Enable("ContentMD5")
		else
			x_Par_Disable("ContentMD5")
		
		
		if (ElementParameters.WhereToGetPostData = "Specified")
		{
			x_Par_Enable("PostData")
			x_Par_Enable("URIEncodePostData")
			x_Par_Disable("InputFile")
			x_Par_Enable("WhichCodepage")
			
			if (ElementParameters.WhichCodepage="utf-8")
				x_Par_Disable("Codepage")
			else
				x_Par_Enable("Codepage")

		}
		else if (ElementParameters.WhereToGetPostData = "File")
		{
			x_Par_Disable("PostData")
			x_Par_Disable("URIEncodePostData")
			x_Par_Disable("WhichCodepage")
			x_Par_Enable("InputFile")

		}
	}
	
	if (ElementParameters.WhereToPutResponseData="Variable")
	{
		x_Par_Enable("ResponseDataVar")
		x_Par_Disable("OutputFile")
	}
	else
	{
		x_Par_Disable("ResponseDataVar")
		x_Par_Enable("OutputFile")
	}
	
	if (ElementParameters.WhichMethod="automatic")
		x_Par_Disable("Method")
	else
		x_Par_Enable("Method")
	
	if (ElementParameters.WhichUserAgent="automatic")
		x_Par_Disable("UserAgent")
	else
		x_Par_Enable("UserAgent")
	
	if (ElementParameters.WhichProxy="custom")
		x_Par_Enable("Proxy")
	else
	{
		x_Par_Disable("Proxy")
		
		if (ElementParameters.WhichProxy="none")
		{
			x_Par_Disable("WhetherBypassProxy")
			x_Par_Disable("BypassProxy")
		}
		else
		{
			x_Par_Enable("WhetherBypassProxy")
			if (ElementParameters.WhetherBypassProxy=true)
				x_Par_Enable("BypassProxy")
			else
				x_Par_Disable("BypassProxy")
		}
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_HTTP_Request(Environment, ElementParameters)
{
	Headers := x_replaceVariables(Environment,ElementParameters.RequestHeaders)
	
	if Headers
		Headers := uriencode(Headers)

	Flags:=x_replaceVariables(Environment,ElementParameters.Flags)
	
	BytesDownloaded:=0
	Options:=""
	
	if (ElementParameters.IsExpression = "expression")
	{
		evRes := x_EvaluateExpression(Environment, ElementParameters.URL)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.URL) "`n`n" evRes.error) 
			return
		}
		else
		{
			URL:=evRes.result
		}
	}
	else if (ElementParameters.IsExpression = "string")
	{
		URL := x_replaceVariables(Environment, ElementParameters.URL)
	}
	else
		URL := ElementParameters.URL


	ResponseDataVar := x_replaceVariables(Environment, ElementParameters.ResponseDataVar)
	if not x_CheckVariableName(ResponseDataVar)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", ResponseDataVar)))
		return
	}
	ResponseHeadersVar := x_replaceVariables(Environment, ElementParameters.ResponseHeadersVar)
	if not x_CheckVariableName(ResponseHeadersVar)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", ResponseHeadersVar)))
		return
	}
	
	postDataAvailable:=false
	if (ElementParameters.WhereToGetPostData="Specified") ;If data should be sent
	{
		PostData:=x_replaceVariables(Environment,ElementParameters.PostData)
		if (PostData)
			PostData:=uriencode(PostData)
		
		if (ElementParameters.WhichCodepage="definedCharset")
		{
			Codepage:=x_replaceVariables(Environment,ElementParameters.Codepage)
			Options.="Charset: " Codepage "`n"
		}
		else if (ElementParameters.WhichCodepage="definedCodepage")
		{
			Codepage:=x_replaceVariables(Environment,ElementParameters.Codepage)
			Options.="Codepage: " Codepage "`n"
		}
		postDataAvailable:=true
	}
	else if (ElementParameters.WhereToGetPostData="File") ;If file should be used
	{
		InputFile := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.InputFile))
		if not FileExist(InputFile)
		{
			x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("Source file"), InputFile)) 
			return
		}
		
		Options.="Upload: " InputFile "`n"
		postDataAvailable:=true
	}
	if (postDataAvailable) ;If data or file should be sent
	{
		if (ElementParameters.WhichContentType="custom")
		{
			Contenttype:=x_replaceVariables(Environment,ElementParameters.Contenttype)
			Options.="Content-Type: " Contenttype "`n"
		}
		if (ElementParameters.WhichContentLength="custom")
		{
			evRes := x_EvaluateExpression(Environment, ElementParameters.Contentlength)
			if (evRes.error)
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Contentlength) "`n`n" evRes.error) 
				return
			}
			else
			{
				Contentlength:=evRes.result
			}
			
			Options.="Content-Length: " ContentLength "`n"
		}
		if (ElementParameters.WhichContentMD5="automatic")
		{
			Options.="Content-MD5:"  "`n"
		}
		if (ElementParameters.WhichContentMD5="custom")
		{
			ContentMD5:=x_replaceVariables(Environment,ElementParameters.ContentMD5)
			Options.="Content-MD5: " ContentMD5 "`n"
		}
	}
	
	
	if (ElementParameters.WhereToPutResponseData="File") ;If file should be used
	{
		OutputFile := x_GetFullPath(Environment, x_replaceVariables(Environment, ElementParameters.OutputFile))
		SplitPath,OutputFile,,OutputFileDir
		if not InStr(FileExist(OutputFileDir), "D") ;Check whether directory exists
		{
			x_finish(Environment, "exception", lang("%1% '%2%' does not exist.",lang("Destination folder"), OutputFileDir)) 
			return
		}
		Options.="SaveAs: " OutputFile "`n"
	}
	
	
	
	
	if (ElementParameters.WhichMethod="Custom")
	{
		Options.="Method: " ElementParameters.Method "`n"
	}
	if (ElementParameters.WhichUserAgent="custom")
	{
		UserAgent:=x_replaceVariables(Environment,ElementParameters.UserAgent)
		Options.="User-Agent: " UserAgent "`n"
	}
	if (ElementParameters.WhichProxy="automatic")
	{
		Options.="AutoProxy" "`n"
	}
	else if (ElementParameters.WhichProxy="custom")
	{
		Proxy:=x_replaceVariables(Environment,ElementParameters.Proxy)
		Options.="Proxy: " Proxy "`n"
	}
	if (ElementParameters.WhetherBypassProxy=true)
	{
		BypassProxy:=x_replaceVariables(Environment,ElementParameters.BypassProxy)
		Options.="ProxyBypass: " BypassProxy "`n"
	}
	
	
	
	;All informations gathered: Perform HTTP Request
	BytesDownloaded := HTTPRequest( URL, PostData, Headers, Options )
	
	if (ElementParameters.WhereToPutResponseData="Variable")
	{
		x_SetVariable(Environment,ResponseDataVar,PostData)
	}
	x_SetVariable(Environment,ResponseHeadersVar,Headers)
	x_SetVariable(Environment,"A_BytesDownloaded",BytesDownloaded, "thread")
	
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_HTTP_Request(Environment, ElementParameters)
{
	;TODO. Can't be stopped yet.
}






