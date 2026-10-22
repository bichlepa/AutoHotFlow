#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\HttpOps.ahk
#Include ..\lib\TextOps.ahk

; Action HTTP request of the package Default (WI-0122): sends one request to an URL and stores the response in a variable or a
; file. Specification: the help text of v1 (help/en/Actions/HTTP_Request.md). Class ID, parameter IDs, defaults, choices and
; language keys are those of v1 (Source_Elements/Default/Actions/HTTP_Request.ahk).
;
; Mode worker: the request goes through WinHTTP (HttpOps) and waits for the network with the timeouts of HttpOps and a job
; deadline of 10 minutes (JobTimeoutMs, the class value; v1 had none). Only http and https. Differences from v1, all in
; MIGRATION M-0147 to M-0149: the Flags field has no effect (WinINet flags have no WinHTTP equivalent); the codepage of the
; post data encodes the body, and a charset name is only a codepage name that AutoHotkey knows; the proxy bypass list
; applies to a custom proxy only; Automatic method is POST with post data and GET without; a status other than 2xx is no
; error (as in v1). The response headers go to their variable as the server sent them.
class Action_HTTP_Request extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Advanced"
    static Stability := "Stable"
    static Icon := ""
    static JobTimeoutMs := 600000

    static Name() => Lang("HTTP Request")
    static Category() => Lang("Internet")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("URL")},
        {type: "Edit", id: "URL", default: "http://www.example.com", content: ["RawString", "String", "Expression"], contentID: "IsExpression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("Post data")},
        {type: "Radio", id: "WhereToGetPostData", default: "NoUpload", result: "Enum", choices: [Lang("Do not upload any data"), Lang("Use following post data"), Lang("Use file as source (upload)")], enum: ["NoUpload", "Specified", "File"]},
        {type: "multiLineEdit", id: "PostData", default: "", content: "String"},
        {type: "Checkbox", id: "URIEncodePostData", default: 0, label: Lang("URI encode post data")},
        {type: "Label", label: Lang("Charset"), size: "small"},
        {type: "Radio", id: "WhichCodepage", default: "utf-8", result: "Enum", choices: [Lang("Use UTF-8 charset"), Lang("Define charset"), Lang("Define codepage")], enum: ["utf-8", "definedCharset", "definedCodepage"]},
        {type: "Edit", id: "Codepage", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path"), size: "small"},
        {type: "File", id: "InputFile", label: Lang("Select file")},
        {type: "Label", label: Lang("Request headers")},
        {type: "multiLineEdit", id: "RequestHeaders", default: "", content: "String"},
        {type: "Label", label: Lang("Response data")},
        {type: "Radio", id: "WhereToPutResponseData", default: "Variable", result: "Enum", choices: [Lang("Write response data to a variable"), Lang("Write response data to file (download)")], enum: ["Variable", "File"]},
        {type: "Label", label: Lang("Output variable"), size: "small"},
        {type: "Edit", id: "ResponseDataVar", default: "HTTPResponseData", content: "VariableName"},
        {type: "Label", label: Lang("File path"), size: "small"},
        {type: "File", id: "OutputFile", default: "HTTPResponseData.html", label: Lang("Select file")},
        {type: "Label", label: Lang("Response headers")},
        {type: "Edit", id: "ResponseHeadersVar", default: "HTTPResponseHeaders", content: "VariableName"},
        {type: "Label", label: Lang("Content type")},
        {type: "Radio", id: "WhichContentType", default: "automatic", result: "Enum", choices: [Lang("Automatic"), Lang("Custom")], enum: ["automatic", "custom"]},
        {type: "ComboBox", id: "Contenttype", default: "", content: "String", result: "string", choices: ["text/plain", "text/html", "text/json", "text/html", "application/x-www-form-urlencoded", "application/octet-stream", "application/json", "application/xml"], WarnIfEmpty: true},
        {type: "Label", label: Lang("Content length")},
        {type: "Radio", id: "WhichContentLength", default: "automatic", result: "Enum", choices: [Lang("Automatic"), Lang("Custom")], enum: ["automatic", "custom"]},
        {type: "Edit", id: "ContentLength", default: "", content: "expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Content MD5")},
        {type: "Radio", id: "WhichContentMD5", default: "none", result: "Enum", choices: [Lang("Do not use"), Lang("Automatic"), Lang("Custom")], enum: ["none", "automatic", "custom"]},
        {type: "Edit", id: "ContentMD5", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Method")},
        {type: "Radio", id: "WhichMethod", default: "automatic", result: "Enum", choices: [Lang("Automatic"), Lang("Custom")], enum: ["automatic", "custom"]},
        {type: "DropDown", id: "Method", default: "GET", result: "enum", choices: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"], enum: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE"]},
        {type: "Label", label: Lang("User agent")},
        {type: "Radio", id: "WhichUserAgent", default: "automatic", result: "Enum", choices: [Lang("Automatic"), Lang("Custom")], enum: ["automatic", "custom"]},
        {type: "Edit", id: "UserAgent", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Flags")},
        {type: "multiLineEdit", id: "Flags", default: "", content: "String"},
        {type: "Label", label: Lang("Proxy")},
        {type: "Radio", id: "WhichProxy", default: "none", result: "Enum", choices: [Lang("No proxy"), Lang("Automatic"), Lang("Custom")], enum: ["none", "automatic", "custom"]},
        {type: "Edit", id: "Proxy", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Bypass proxy"), size: "small"},
        {type: "Checkbox", id: "WhetherBypassProxy", default: 0, label: Lang("Don't use proxy to access following website")},
        {type: "Edit", id: "BypassProxy", default: "", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("HTTP Request") " - " TextOps.Par(params, "URL")

    static CheckSettings(form, params, staticValues) {
        post := TextOps.Par(params, "WhereToGetPostData")
        upload := (post != "NoUpload")
        specified := (post = "Specified")
        codepage := TextOps.Par(params, "WhichCodepage")
        form.Enable("PostData", specified)
        form.Enable("URIEncodePostData", specified)
        form.Enable("InputFile", post = "File")
        form.Enable("WhichCodepage", specified)
        form.Enable("Codepage", specified && codepage != "utf-8")
        form.Enable("WhichContentType", upload)
        form.Enable("Contenttype", upload && TextOps.Par(params, "WhichContentType") = "custom")
        form.Enable("WhichContentLength", upload)
        form.Enable("ContentLength", upload && TextOps.Par(params, "WhichContentLength") = "custom")
        form.Enable("WhichContentMD5", upload)
        form.Enable("ContentMD5", upload && TextOps.Par(params, "WhichContentMD5") = "custom")
        toVariable := (TextOps.Par(params, "WhereToPutResponseData") != "File")
        form.Enable("ResponseDataVar", toVariable)
        form.Enable("OutputFile", !toVariable)
        form.Enable("Method", TextOps.Par(params, "WhichMethod") = "custom")
        form.Enable("UserAgent", TextOps.Par(params, "WhichUserAgent") = "custom")
        custom := (TextOps.Par(params, "WhichProxy") = "custom")
        form.Enable("Proxy", custom)
        form.Enable("WhetherBypassProxy", custom)
        form.Enable("BypassProxy", custom && DialogOps.Truthy(TextOps.Par(params, "WhetherBypassProxy")))
    }

    ; The choices (radio buttons and checkboxes) of a request, with the defaults of the parameters when a flow does not
    ; hold them (a flow written by hand, or a flow built by a test). The content fields are evaluated by ctx.EvalParams.
    static Choices(params) {
        return {
            post: this.Opt(params, "WhereToGetPostData", "NoUpload"),
            codepage: this.Opt(params, "WhichCodepage", "utf-8"),
            uriEncode: DialogOps.Truthy(this.Opt(params, "URIEncodePostData", 0)),
            contentType: this.Opt(params, "WhichContentType", "automatic"),
            contentLength: this.Opt(params, "WhichContentLength", "automatic"),
            contentMd5: this.Opt(params, "WhichContentMD5", "none"),
            response: this.Opt(params, "WhereToPutResponseData", "Variable"),
            method: this.Opt(params, "WhichMethod", "automatic"),
            userAgent: this.Opt(params, "WhichUserAgent", "automatic"),
            proxy: this.Opt(params, "WhichProxy", "none"),
            bypass: DialogOps.Truthy(this.Opt(params, "WhetherBypassProxy", 0))
        }
    }

    ; The value of a parameter of the flow, or its default when the flow does not hold it.
    static Opt(params, name, default) => params.HasProp(name) ? params.%name% : default

    ; The parameters that this request does not use, so that they are not evaluated (v1 evaluated only what it used).
    static SkipList(params) {
        c := this.Choices(params)
        upload := (c.post != "NoUpload")
        skip := []
        if (c.post = "Specified") {
            skip.Push("InputFile")
            if (c.codepage = "utf-8")
                skip.Push("Codepage")
        } else if (c.post = "File") {
            skip.Push("PostData", "URIEncodePostData", "Codepage")
        } else {
            skip.Push("PostData", "URIEncodePostData", "InputFile", "Codepage")
        }
        if (!upload || c.contentType != "custom")
            skip.Push("Contenttype")
        if (!upload || c.contentLength != "custom")
            skip.Push("ContentLength")
        if (!upload || c.contentMd5 != "custom")
            skip.Push("ContentMD5")
        if (c.response = "File")
            skip.Push("ResponseDataVar")
        else
            skip.Push("OutputFile")
        if (c.userAgent != "custom")
            skip.Push("UserAgent")
        if (c.proxy != "custom")
            skip.Push("Proxy")
        if (!c.bypass || c.proxy != "custom")
            skip.Push("BypassProxy")
        return skip
    }

    static Run(ctx, params) {
        c := this.Choices(params)
        p := ctx.EvalParams(params, this.SkipList(params))
        HttpOps.CheckUrl(p.URL)
        hasBody := (c.post != "NoUpload")
        body := Buffer(0)
        if (c.post = "Specified") {
            text := p.PostData
            if (c.uriEncode)
                text := TextOps.UriEncode(text)
            body := HttpOps.Encode(text, this.Encoding(c, p))
        } else if (c.post = "File") {
            if (FileOps.Attr(p.InputFile) = "")
                throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), p.InputFile))
            if (FileOps.IsFolder(FileOps.Attr(p.InputFile)))
                throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Source file"), p.InputFile))
            body := FileRead(p.InputFile, "RAW")
        }
        headers := []
        if (hasBody && c.contentType = "custom")
            headers.Push(["Content-Type", p.Contenttype])
        if (hasBody && c.contentLength = "custom")
            headers.Push(["Content-Length", p.ContentLength])
        if (hasBody && c.contentMd5 = "automatic")
            headers.Push(["Content-MD5", HttpOps.ContentMd5(body)])
        else if (hasBody && c.contentMd5 = "custom")
            headers.Push(["Content-MD5", p.ContentMD5])
        if (c.userAgent = "custom")
            headers.Push(["User-Agent", p.UserAgent])
        for header in HttpOps.ParseHeaders(p.RequestHeaders)
            headers.Push(header)
        method := (c.method = "custom") ? this.Opt(params, "Method", "GET") : (hasBody ? "POST" : "GET")
        if (c.response = "File") {
            FileOps.Guard(Lang("Destination file"), TextOps.Par(params, "OutputFile"), p.OutputFile)
            if (FileOps.IsFolder(FileOps.Attr(p.OutputFile)))
                throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Destination file"), p.OutputFile))
            SplitPath(p.OutputFile, , &outDir)
            if (outDir != "" && !DirExist(outDir))
                throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Destination folder"), outDir))
        }
        response := this.Fetch(c, p, method, headers, body)
        if (c.response = "File")
            this.WriteFile(p.OutputFile, response.body)
        else
            FileOps.SetOutput(ctx, p.ResponseDataVar, response.text)
        FileOps.SetOutput(ctx, p.ResponseHeadersVar, response.headers)
        FileOps.SetOutput(ctx, "A_BytesDownloaded", response.body.Size, "thread")
        ctx.Finish("normal")
    }

    ; The codepage of the post data: UTF-8, a codepage number or a name that AutoHotkey knows (StrPut).
    static Encoding(c, p) {
        if (c.codepage = "utf-8")
            return "UTF-8"
        if (Trim(p.Codepage) = "")
            throw ElementError(Lang("%1% is not specified.", Lang("Codepage")))
        return IsInteger(Trim(p.Codepage)) ? "CP" Trim(p.Codepage) : Trim(p.Codepage)
    }

    ; One request with the timeouts of HttpOps. Returns an object with the status, the text (decoded by WinHTTP), the
    ; headers and the body (Buffer). Any failure of the request ends the element with the error of WinHTTP.
    static Fetch(c, p, method, headers, body) {
        http := HttpOps.Client()
        this.SetProxy(http, c, p)
        http.SetTimeouts(HttpOps.CONNECT_MS, HttpOps.CONNECT_MS, HttpOps.IO_MS, HttpOps.IO_MS)
        try {
            http.Open(method, p.URL, false)
            for header in headers
                http.SetRequestHeader(header[1], header[2])
            if (c.post != "NoUpload") {
                wrapped := HttpOps.ToSafeArray(body)
                try http.Send(wrapped.value)
                finally HttpOps.FreeSafeArray(wrapped)
            } else {
                http.Send()
            }
            result := {status: http.Status, headers: http.GetAllResponseHeaders()}
            result.body := HttpOps.FromSafeArray(http.ResponseBody)
            result.text := (c.response = "File") ? "" : http.ResponseText
        } catch as err {
            if (err is ElementError)
                throw err
            throw ElementError(Lang("The HTTP request to '%1%' failed: %2%", p.URL, err.Message))
        }
        return result
    }

    ; The proxy of the request: "none" is a direct connection, "automatic" the proxy of the system (WinHTTP default), "custom"
    ; the proxy server with the bypass list when it is set.
    static SetProxy(http, c, p) {
        switch c.proxy {
            case "none":
                http.SetProxy(1)
            case "custom":
                http.SetProxy(2, p.Proxy, c.bypass ? p.BypassProxy : "")
            default:
                http.SetProxy(0)
        }
    }

    ; Writes the response body to a file (the file is replaced).
    static WriteFile(path, body) {
        try {
            file := FileOpen(path, "w")
            file.RawWrite(body)
            file.Close()
        } catch as err {
            throw ElementError(Lang("%1% '%2%' could not be written: %3%", Lang("Destination file"), path, err.Message))
        }
    }
}
