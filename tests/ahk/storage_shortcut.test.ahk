#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/storage/ShortcutFile.ahk (WI-0133, REQ-TRG-240): create, unchanged, repaired, remove, and the path
; rules. Every shortcut is written into a temporary folder of this test (never the desktop or the start menu).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\storage\ShortcutFile.ahk

; A fresh folder for one case; it is removed at the end of the run.
Folder() {
    dir := A_Temp "\ahf_storage_shortcut_" A_TickCount "_" A_Index
    DirCreate(dir)
    return dir
}

Case1() {
    dir := Folder()
    path := dir "\Flow test.lnk"
    res := ShortcutFile.Write(path, A_AhkPath, '"x.ahk" "--command=Trigger|Flow 1|element0000000002"', dir)
    Assert.Equal(res["action"], "created", "a new shortcut is created")
    Assert.True(FileExist(path) != "", "the file exists")
    FileGetShortcut(path, &target, &wd, &args)
    Assert.Equal(target, A_AhkPath, "the target")
    Assert.Equal(args, '"x.ahk" "--command=Trigger|Flow 1|element0000000002"', "the arguments")
    Assert.Equal(RTrim(wd, "\"), RTrim(dir, "\"), "the working folder")
    again := ShortcutFile.Write(path, A_AhkPath, '"x.ahk" "--command=Trigger|Flow 1|element0000000002"', dir)
    Assert.Equal(again["action"], "unchanged", "the same values change nothing")
    other := ShortcutFile.Write(path, A_AhkPath, '"x.ahk" "--command=Trigger|Flow 2|element0000000002"', dir)
    Assert.Equal(other["action"], "repaired", "other arguments are repaired")
    Assert.Equal(ShortcutFile.Remove(path)["action"], "removed", "remove deletes the file")
    Assert.Equal(ShortcutFile.Remove(path)["action"], "none", "removing again finds no file")
    DirDelete(dir, true)
}

Case2() {
    dir := Folder()
    path := dir "\Not a shortcut.lnk"
    FileAppend("plain text", path)
    res := ShortcutFile.Write(path, A_AhkPath, "a", dir)
    Assert.Equal(res["action"], "repaired", "a file that is no shortcut is replaced")
    Assert.Equal(ShortcutFile.Remove(path)["action"], "removed")
    DirDelete(dir, true)
}

Case3() {
    dir := Folder()
    ; relative paths, other extensions, a folder that does not exist and a path with a line break are refused
    bads := ["relative.lnk", "..\x.lnk", dir "\x.txt", dir "\x" "`n" ".lnk"]
    for bad in bads {
        Assert.Throws(ShortcutFile.Write.Bind(ShortcutFile, bad, A_AhkPath, "a", dir), AhfError, "refused: " bad)
        Assert.Throws(ShortcutFile.Remove.Bind(ShortcutFile, bad), AhfError, "remove refuses: " bad)
    }
    missing := dir "\no such folder\x.lnk"
    e := Assert.Throws(ShortcutFile.Write.Bind(ShortcutFile, missing, A_AhkPath, "a", dir), AhfError, "a folder that does not exist")
    Assert.Equal(e.code, ErrCode.NOT_FOUND, "the code is not_found")
    e := Assert.Throws(ShortcutFile.Write.Bind(ShortcutFile, dir "\x.lnk", "", "a", dir), AhfError, "an empty target")
    Assert.Equal(e.code, ErrCode.BAD_PAYLOAD, "the code is bad_payload")
    DirDelete(dir, true)
}

TestRun.Case("Write creates, keeps and repairs a shortcut; Remove deletes it", Case1)
TestRun.Case("A file that is no shortcut is replaced", Case2)
TestRun.Case("Relative paths, other extensions and missing folders are refused", Case3)

TestRun.Finish()
