#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TarOps.ahk
#Include ..\lib\TextOps.ahk

; Action Extract files of the package Default (WI-0122): unpacks an archive into a folder. Specification: the help text of
; v1 (help/en/Actions/Extract_files.md). Class ID, parameter IDs, defaults and choices are those of v1
; (Source_Elements/Default/Actions/Extract_files.ahk).
;
; Mode worker: tar.exe of Windows reads the archive (TarOps), not 7za.exe (v1). The format is found by tar.exe itself, so
; the choice of the format is not needed (M-0136): zip, 7z, tar and the tar archives with gzip, bzip2, xz or lzma are read;
; a single file compressed with gzip, bzip2, xz or lzma (without tar) is not an archive and ends with an exception.
; Before anything is written, every entry is checked: an entry that would leave the folder (an absolute name, a drive, ".."),
; or a link or a device, refuses the whole archive (zip-slip, FileOps.Guard for the folder). Existing files of the same name
; in the folder are replaced, as v1 did (MIGRATION M-0137).
class Action_Extract_files extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Advanced"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Extract files")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source archive")},
        {type: "File", id: "zipfile", label: Lang("Select an archive"), filter: Lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; .tbz2; .tbz; .tar; .z; .taz; .lzma)"},
        {type: "Label", label: Lang("Destination folder")},
        {type: "Folder", id: "folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Options")},
        {type: "Label", label: Lang("Format"), size: "small"},
        {type: "DropDown", id: "zipformat", default: "*", choices: ["*", "zip", "7z", "xz", "tar", "gzip", "BZIP2", "Z", "lzma"], result: "string"}
    ]

    static GenerateName(ctx, params) => Lang("Extract files") " - " TextOps.Par(params, "zipfile") " - " TextOps.Par(params, "folder")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (FileOps.IsWild(p.zipfile))
            throw FileOps.NoWildcard(p.zipfile)
        FileOps.CheckFileSource(p.zipfile)
        if (FileOps.Attr(p.folder) = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Destination folder"), p.folder))
        if (!FileOps.IsFolder(FileOps.Attr(p.folder)))
            throw ElementError(Lang("%1% '%2%' is not a folder.", Lang("Destination folder"), p.folder))
        FileOps.Guard(Lang("Destination folder"), TextOps.Par(params, "folder"), p.folder)
        archive := TarOps.Absolute(p.zipfile)
        folder := TarOps.Absolute(p.folder)
        TarOps.CheckEntries(archive)
        TarOps.Extract(archive, folder)
        ctx.Finish("normal")
    }
}
