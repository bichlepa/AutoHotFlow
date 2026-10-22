#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TarOps.ahk
#Include ..\lib\TextOps.ahk

; Action Compress files of the package Default (WI-0122): packs one file or folder into an archive. Specification: the help
; text of v1 (help/en/Actions/Compress_files.md). Class ID, parameter IDs, defaults and choices are those of v1
; (Source_Elements/Default/Actions/Compress_files.ahk).
;
; Mode worker: the archive is written by tar.exe of Windows (TarOps), not by 7za.exe (v1). The formats zip, 7z, tar, gzip,
; BZIP2 and xz: gzip, BZIP2 and xz compress the tar archive, a single file is not compressed without it (MIGRATION M-0136).
; An existing archive of that name is replaced (MIGRATION M-0137). A folder is packed with its contents.
class Action_Compress_files extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Advanced"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Compress files")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source file")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Destination archive")},
        {type: "File", id: "zipfile", label: Lang("Select a file path for the compressed file"), filter: Lang("Archive") " (.zip; .7z; .xz; .gz; .gzip; .tgz; .bz2; .bzip2; .tbz2; .tbz; .tar)", options: "S"},
        {type: "Label", label: Lang("Options")},
        {type: "Label", label: Lang("Format"), size: "small"},
        {type: "DropDown", id: "zipformat", default: "zip", choices: ["zip", "7z", "xz", "tar", "gzip", "BZIP2"], result: "string"}
    ]

    static GenerateName(ctx, params) => Lang("Compress files") " - " TextOps.Par(params, "zipformat") " - " TextOps.Par(params, "file") " - " TextOps.Par(params, "zipfile")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (FileOps.IsWild(p.file))
            throw FileOps.NoWildcard(p.file)
        if (FileOps.Attr(p.file) = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), p.file))
        FileOps.Guard(Lang("Destination archive"), TextOps.Par(params, "zipfile"), p.zipfile)
        if (FileOps.IsFolder(FileOps.Attr(p.zipfile)))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Destination file"), p.zipfile))
        SplitPath(p.zipfile, , &archiveDir)
        if (archiveDir != "" && !DirExist(archiveDir))
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Destination folder"), archiveDir))
        source := TarOps.Absolute(p.file)
        SplitPath(source, &name, &parent)
        TarOps.Create(TarOps.Absolute(p.zipfile), p.zipformat, parent, name)
        ctx.Finish("normal")
    }
}
