#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The archive functions of the package Default (WI-0122): tar.exe of Windows (bsdtar, the same tool as the .ahf export,
; WI-0081) writes and reads the archives of the Compress and Extract elements. No 7za.exe (v1).
;
; The worker runs tar.exe without a window: cmd.exe starts it with its output in a job folder and writes the answer
; "ok" or "fail" into a second file. The worker waits for the process with a deadline (ProcessWaitClose, TIMEOUT_S); a run
; that is over its deadline is killed with its child processes. The output of tar is written in the ANSI code page (a name
; outside it is not readable in the listing, F-0131); the checks of the names do not need the exact names.
;
; What tar.exe cannot do (checked on this machine, bsdtar 3.8.9): it reads and writes archives only (tar, tar.gz, tar.bz2,
; tar.xz, tar.lzma, zip, 7z), not a single file compressed with gzip, bzip2 or xz (MIGRATION M-0141). The Z format is not
; checked. Names that cmd.exe cannot pass (a percent sign, a quote, a line break) are refused.
class TarOps {
    static TIMEOUT_S := 900        ; one tar run that is still going after this long is killed
    static OUTPUT_MAX := 2000      ; characters of the output that an error message shows
    static seq := 0                ; counter of the job folders of this process

    static Exe() => A_WinDir "\System32\tar.exe"

    ; The options of tar that write a format of the Compress element (the v1 names of the drop-down).
    static WriteOptions(format) {
        switch format {
            case "zip": return "--format zip"
            case "7z": return "--format 7zip"
            case "tar": return ""
            case "gzip": return "-z"          ; a tar archive compressed with gzip (M-0141)
            case "BZIP2": return "-j"         ; a tar archive compressed with bzip2 (M-0141)
            case "xz": return "-J"            ; a tar archive compressed with xz (M-0141)
        }
        throw ElementError(Lang("The archive format '%1%' is not known.", format))
    }

    ; A path or name in the command line of cmd.exe: quoted, and refused when cmd.exe cannot pass it.
    static Quote(text, label) {
        if (InStr(text, "%") || InStr(text, '"') || InStr(text, "`n") || InStr(text, "`r"))
            throw ElementError(Lang("The path of '%1%' has a percent sign, a quote or a line break, which cannot be passed to tar.exe.", label))
        return '"' text '"'
    }

    ; The full path of a path (GetFullPathNameW). Used for the folders the archive is taken from, never to act on them.
    static Absolute(path) {
        buf := Buffer(2048)
        n := DllCall("GetFullPathNameW", "str", path, "uint", 1024, "ptr", buf, "ptr", 0, "uint")
        return (n > 0 && n < 1024) ? StrGet(buf, n, "UTF-16") : path
    }

    ; Runs tar.exe with args (already quoted) in a job folder and returns its output (the listing, or the text of the
    ; error when it fails). Throws ElementError with the reason when tar fails, cannot start or is over its deadline.
    static Exec(args, what) {
        TarOps.seq += 1
        dir := A_Temp "\ahf-tar-" ProcessExist() "-" TarOps.seq
        DirCreate(dir)    ; arch-ok: file-io the job folder of one tar run (the calling element is a worker)
        out := dir "\out.txt", err := dir "\err.txt", code := dir "\code.txt"
        try {
            cmdLine := A_ComSpec ' /d /c ""' TarOps.Exe() '" ' args ' > "' out '" 2> "' err '" && (echo ok> "' code '") || (echo fail> "' code '")"'
            try
                Run(cmdLine, , "Hide", &pid)
            catch as e
                throw ElementError(Lang("%1% could not be started: %2%", what, e.Message))
            if (ProcessWaitClose(pid, TarOps.TIMEOUT_S)) {
                Run('taskkill /T /F /PID ' pid, , "Hide")
                throw ElementError(Lang("%1% did not finish in %2% seconds.", what, TarOps.TIMEOUT_S))
            }
            answer := TarOps._Text(code)
            text := TarOps._Text(out)
            if (answer = "ok")
                return text
            reason := TarOps._Text(err)
            if (reason = "")
                reason := text
            if (reason = "")
                reason := Lang("tar.exe failed.")
            if (StrLen(reason) > TarOps.OUTPUT_MAX)
                reason := SubStr(reason, 1, TarOps.OUTPUT_MAX) "..."
            throw ElementError(Lang("%1% failed: %2%", what, reason))
        } finally {
            TarOps._Discard(dir)
        }
    }

    ; The text of a job file in the ANSI code page, trimmed; "" when the file is missing or cannot be read.
    static _Text(path) {
        if (FileExist(path) = "")
            return ""
        try
            return Trim(FileRead(path, "CP0"), " `r`n`t")    ; arch-ok: file-io the output of tar (a worker job file)
        catch
            return ""
    }

    ; Removes a job folder. A folder that a process still holds open is left (the next run uses a new folder).
    static _Discard(dir) {
        try DirDelete(dir, true)    ; arch-ok: file-io the job folder of one tar run (the calling element is a worker)
    }

    ; The names and the type letters of the entries of an archive (tar -tf and tar -tvf, the same order). Throws when an
    ; entry leaves the destination folder (a name with a drive, a root, or ".."), or when it is a link or a device: such an
    ; archive is refused as a whole, before anything is written.
    static CheckEntries(archive) {
        q := TarOps.Quote(archive, Lang("Source archive"))
        names := StrSplit(RegExReplace(TarOps.Exec("-tf " q, Lang("The listing of the archive")), "\r?\n$", ""), "`n", "`r")
        kinds := StrSplit(RegExReplace(TarOps.Exec("-tvf " q, Lang("The listing of the archive")), "\r?\n$", ""), "`n", "`r")
        if (names.Length != kinds.Length)
            throw ElementError(Lang("The listing of the archive could not be read."))
        for i, name in names {
            if (name = "")
                continue
            if (!TarOps.IsSafeName(name))
                throw ElementError(Lang("The archive contains an entry that leaves the destination folder: '%1%'", name))
            kind := SubStr(kinds[i], 1, 1)
            if (kind != "-" && kind != "d")
                throw ElementError(Lang("The archive contains a link or a device, which is not extracted: '%1%'", name))
        }
    }

    ; True for an entry name that stays inside the folder it is extracted to: relative, without a drive and without "..".
    static IsSafeName(name) {
        if (SubStr(name, 1, 1) = "/" || SubStr(name, 1, 1) = "\" || RegExMatch(name, "^[A-Za-z]:"))
            return false
        for part in StrSplit(StrReplace(name, "\", "/"), "/") {
            if (part = "..")
                return false
        }
        return true
    }

    ; Extracts the archive into folder (tar detects the format of the archive itself).
    static Extract(archive, folder) {
        TarOps.Exec("-xf " TarOps.Quote(archive, Lang("Source archive")) " -C " TarOps.Quote(folder, Lang("Destination folder")),
            Lang("Extracting the archive"))
    }

    ; Writes the archive. An existing archive is replaced (MIGRATION M-0142).
    static Create(archive, format, parent, name) {
        opts := TarOps.WriteOptions(format)
        args := (opts = "" ? "" : opts " ") "-cf " TarOps.Quote(archive, Lang("Destination archive"))
            . " -C " TarOps.Quote(parent, Lang("Source file")) " " TarOps.Quote(name, Lang("Source file"))
        TarOps.Exec(args, Lang("Compressing the files"))
    }
}
