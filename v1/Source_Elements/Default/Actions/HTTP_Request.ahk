
;Name of the element
Element_getName_Action_HTTP_Request()
{
	return x_lang("HTTP_Request")
}

;Category of the element
Element_getCategory_Action_HTTP_Request()
{
	return x_lang("Internet")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_HTTP_Request()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Advanced"
}

;Icon file name which will be shown in the background of the element
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
	
	parametersToEdit.push({type: "Label", label: x_lang("URL")})
	parametersToEdit.push({type: "Edit", id: "URL", default: "http://www.example.com", content: ["RawString", "String", "Expression"], contentID: "IsExpression", contentDefault: "string", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Post data")})
	parametersToEdit.push({type: "Radio", id: "WhereToGetPostData", default: "NoUpload", result: "Enum", choices: [x_lang("Do not upload any data"), x_lang("Use following post data"), x_lang("Use file as source (upload)")], enum: ["NoUpload", "Specified", "File"]})
	parametersToEdit.push({type: "multiLineEdit", id: "PostData", default: "", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "URIEncodePostData", default: 0, label: x_lang("URI encode post data")})
	parametersToEdit.push({type: "Label", label: x_lang("Charset"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "WhichCodepage", default: "utf-8", result: "Enum", choices: [x_lang("Use UTF-8 charset"), x_lang("Define charset"), x_lang("Define codepage")], enum: ["utf-8", "definedCharset", "definedCodepage"]})
	parametersToEdit.push({type: "Edit", id: "Codepage", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "InputFile", label: x_lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Request headers")})
	parametersToEdit.push({type: "multiLineEdit", id: "RequestHeaders", default: "", content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Response data")})
	parametersToEdit.push({type: "Radio", id: "WhereToPutResponseData", default: "Variable", result: "Enum", choices: [x_lang("Write response data to a variable"), x_lang("Write response data to file (download)")], enum: ["Variable", "File"]})
	parametersToEdit.push({type: "Label", label: x_lang("Output variable"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ResponseDataVar", default: "HTTPResponseData", content: "VariableName"})
	;~ parametersToEdit.push({type: "Checkbox", id: "KeepBinary", default: 0, label: langeeee("Don't convert to codepage of AHF. Keep binary instead.")}) ;TODO Binary data
	parametersToEdit.push({type: "Label", label: x_lang("File path"), size: "small"})
	parametersToEdit.push({type: "File", id: "OutputFile", default: "HTTPResponseData.html", label: x_lang("Select file")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Response headers")})
	parametersToEdit.push({type: "Edit", id: "ResponseHeadersVar", default: "HTTPResponseHeaders", content: "VariableName"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Content type")})
	parametersToEdit.push({type: "Radio", id: "WhichContentType", default: "automatic", result: "Enum", choices: [x_lang("Automatic"), x_lang("Custom")], enum: ["automatic", "custom"]})
	contentTyes := ["text/plain", "text/html", "text/json", "text/html", "application/x-www-form-urlencoded", "application/octet-stream", "application/json", "application/xml"]
	parametersToEdit.push({type: "ComboBox", id: "Contenttype", default: "", content: "String", result: "string", choices: contentTyes, WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Content length")})
	parametersToEdit.push({type: "Radio", id: "WhichContentLength", default: "automatic", result: "Enum", choices: [x_lang("Automatic"), x_lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "ContentLength", default: "", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Content MD5")})
	parametersToEdit.push({type: "Radio", id: "WhichContentMD5", default: "none", result: "Enum", choices: [x_lang("Do not use"), x_lang("Automatic"), x_lang("Custom")], enum: ["none", "automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "ContentMD5", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "WhichMethod", default: "automatic", result: "Enum", choices: [x_lang("Automatic"), x_lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "DropDown", id: "Method", default: "GET", result: "enum", choices: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"], enum: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("User agent")})
	parametersToEdit.push({type: "Radio", id: "WhichUserAgent", default: "automatic", result: "Enum", choices: [x_lang("Automatic"), x_lang("Custom")], enum: ["automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "UserAgent", default: "", content: "String", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Flags")})
	parametersToEdit.push({type: "multiLineEdit", id: "Flags", default: "", content: "String"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Proxy")})
	parametersToEdit.push({type: "Radio", id: "WhichProxy", default: "none", result: "Enum", choices: [x_lang("No proxy"), x_lang("Automatic"), x_lang("Custom")], enum: ["none", "automatic", "custom"]})
	parametersToEdit.push({type: "Edit", id: "Proxy", default: "", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Bypass proxy"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "WhetherBypassProxy", default: 0, label: x_lang("Don't use proxy to access following website")})
	parametersToEdit.push({type: "Edit", id: "BypassProxy", default: "", content: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_HTTP_Request(Environment, ElementParameters)
{
	return x_lang("HTTP_Request") " - " ElementParameters.URL 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_HTTP_Request(Environment, ElementParameters, staticValues)
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
		
		x_Par_Disable("Contenttype", ElementParameters.WhichContentType="automatic")
		
		x_Par_Enable("WhichContentLength")
		
		x_Par_Disable("ContentLength", ElementParameters.WhichContentLength="automatic")
		
		x_Par_Enable("WhichContentMD5")
		
		x_Par_Disable("ContentMD5", ElementParameters.WhichContentLength="automatic")
		
		
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
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["PostData", "Codepage", "InputFile", "Contenttype", "Contentlength", "ContentMD5", "OutputFile", "UserAgent", "Proxy", "BypassProxy"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; prepare variable where we will write options and RequestHeaders for HTTPRequest function
	RequestHeaders:=""
	Options:=""
	
	; find out whether we have POST data 
	postDataAvailable := false
	if (EvaluatedParameters.WhereToGetPostData = "Specified") ;If data should be sent
	{
		; POST data from variable should be sent

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["PostData"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		; check whether charset or codepage is defined
		if (EvaluatedParameters.WhichCodepage = "definedCharset")
		{
			; charset is defined. Add it to options.
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Codepage"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			Options .= "Charset: " EvaluatedParameters.Codepage "`n"
		}
		else if (EvaluatedParameters.WhichCodepage = "definedCodepage")
		{
			; codepage is defined. Add it to options.
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Codepage"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}
			
			Options .= "Codepage: " EvaluatedParameters.Codepage "`n"
		}

		postDataAvailable := true
	}
	else if (EvaluatedParameters.WhereToGetPostData = "File") ;If file should be used
	{
		; POST data from file should be sent

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["InputFile"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		; add the file to options
		Options .= "Upload: " InputFile "`n"
		postDataAvailable := true
	}

	if (postDataAvailable) ;If data or file should be sent
	{
		; we got some post data. Evaluate more related options.

		if (EvaluatedParameters.WhichContentType = "custom")
		{
			; custom content type is set

			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Contenttype"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			; add content type to options
			RequestHeaders .= "Content-Type: " EvaluatedParameters.Contenttype "`n"
		}
		if (EvaluatedParameters.WhichContentLength = "custom")
		{
			; custom content length is set

			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Contentlength"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			; add content length to options
			RequestHeaders.="Content-Length: " ContentLength "`n"
		}

		if (EvaluatedParameters.WhichContentMD5 = "automatic")
		{
			; MD5 should be calculated

			; this will calculate the MD5 automatically
			RequestHeaders .= "Content-MD5:"  "`n"
		}
		if (EvaluatedParameters.WhichContentMD5 = "custom")
		{
			; Custom MD5 checksum should be added

			; evaluate more parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["ContentMD5"])
			if (EvaluatedParameters._error)
			{
				return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			}

			; add MD5 to options
			RequestHeaders .= "Content-MD5: " ContentMD5 "`n"
		}
	}
	
	if (EvaluatedParameters.WhereToPutResponseData = "File") ;If file should be used
	{
		; output should be saved to file. Add option
		
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["OutputFile"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		;Check whether directory exists
		SplitPath, % EvaluatedParameters.OutputFile,, OutputFileDir
		if not InStr(FileExist(OutputFileDir), "D")
		{
			x_finish(Environment, "exception", x_lang("%1% '%2%' does not exist.", x_lang("Destination folder"), OutputFileDir)) 
			return
		}

		; add output file path to options
		Options.="SaveAs: " EvaluatedParameters.OutputFile "`n"
	}
	
	if (EvaluatedParameters.WhichMethod = "Custom")
	{
		; A specific method should be used. Add it to the options
		Options .= "Method: " EvaluatedParameters.Method "`n"
	}
	if (EvaluatedParameters.WhichUserAgent = "custom")
	{
		; A specific user agent should be used. Add it to the options
		
		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["UserAgent"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}
		
		; Add custom user agent to options.
		RequestHeaders .= "User-Agent: " EvaluatedParameters.UserAgent "`n"
	}
	if (EvaluatedParameters.WhichProxy = "automatic")
	{
		; automatic proxy should be used. Add it to options.
		Options .= "AutoProxy" "`n"
	}
	else if (EvaluatedParameters.WhichProxy = "custom")
	{
		; custom proxy should be used.

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Proxy"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}

		; Add custom proxy to options.
		Options .= "Proxy: " Proxy "`n"
	}
	if (EvaluatedParameters.WhetherBypassProxy = true)
	{
		; proxy should be bypassed

		; evaluate more parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["BypassProxy"])
		if (EvaluatedParameters._error)
		{
			return x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		}

		; Add bypass proxy to options.
		Options .= "ProxyBypass: " BypassProxy "`n"
	}
	
	
	; URI encode headers and post data (if any)
	if (postDataAvailable)
	{
		if (EvaluatedParameters.URIEncodePostData)
			PostData := x_UriEncode(EvaluatedParameters.PostData)
		Else
			PostData := EvaluatedParameters.PostData
	}
	RequestHeaders.= "`n" EvaluatedParameters.RequestHeaders
	
	;MsgBox, %  "PostData`n" PostData "`n`nHeaders`n" RequestHeaders "`n`nOptions`n" Options
	;All informations gathered: Perform HTTP Request
	BytesDownloaded := Default_Lib_HTTPRequest(EvaluatedParameters.URL, PostData, RequestHeaders, Options)
	
	if (EvaluatedParameters.WhereToPutResponseData = "Variable")
	{
		; response data should be written to a variable

		; write response to output variable
		x_SetVariable(Environment, EvaluatedParameters.ResponseDataVar, PostData)
	}
	; write response headers to output variable
	x_SetVariable(Environment, EvaluatedParameters.ResponseHeadersVar, Headers)

	; write downloaded byte count to a thread variable
	x_SetVariable(Environment, "A_BytesDownloaded", BytesDownloaded, "thread")
	
	; finish
	x_finish(Environment, "normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_HTTP_Request(Environment, ElementParameters)
{
	;TODO. Can't be stopped yet.
}






