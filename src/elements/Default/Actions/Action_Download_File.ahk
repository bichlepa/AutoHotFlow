#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Download file of the package Default (WI-0122): downloads the file of an URL to a file. Specification: the help text
; of v1 (help/en/Actions/Download_File.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Download_file.ahk).
;
; Mode worker: the download (AutoHotkey Download, the proxy of the Internet settings of the user) waits for the network. It
; has a job deadline of 10 minutes (JobTimeoutMs, the class value; v1 had none, M-0146): a longer download ends with
; "worker timeout" and the partial file stays. The target is a file; a folder or a drive root is refused (FileOps.Guard).
; AutoHotkey Download writes the body of an error page too, as v1 did (the download can "succeed" for a missing file).
class Action_Download_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""
    static JobTimeoutMs := 600000

    static Name() => Lang("Download File")
    static Category() => Lang("File") "|" Lang("Internet")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("URL")},
        {type: "Edit", id: "URL", default: "http://www.example.com", content: ["RawString", "String", "Expression"], contentID: "IsExpression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select file"), default: "%A_Desktop%\Downloaded example.html"}
    ]

    static GenerateName(ctx, params) => Lang("Download File") " - " TextOps.Par(params, "URL") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.Guard(Lang("Destination file"), TextOps.Par(params, "file"), p.file)
        if (FileOps.IsFolder(FileOps.Attr(p.file)))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Destination file"), p.file))
        SplitPath(p.file, , &fileDir)
        if (fileDir != "" && !DirExist(fileDir))
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Destination folder"), fileDir))
        try Download(p.URL, p.file)
        catch
            throw ElementError(Lang("Couldn't download URL '%1%' to file '%2%'", p.URL, p.file))
        ctx.Finish("normal")
    }
}
