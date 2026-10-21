#Requires AutoHotkey v2.0
; Unit tests for the WebView2 parts of the help that need no window (WI-0115): the COM handler of our own (its vtable and
; Invoke, called through ComCall as a COM caller would), the loader check (no file, and the setup file when it is there)
; and the viewer's failure path (a failure is reported once, and nothing else runs). The window and the browser engine
; are the owner's gui test (tests/fault/test_help_webview2_gui.py). The test machine has the WebView2 runtime (Windows 11).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\help\WebView2Viewer.ahk

BoomInvoke(a, b) {
    throw Error("boom")
}

HandlerIsAComObject() {
    got := []
    h := ComHandler((a, b) => got.Push(a "," b))
    Assert.Equal(ComCall(3, h.Ptr, "Ptr", 5, "Ptr", 7), 0, "Invoke returns S_OK")
    Assert.Equal(got[1], "5,7", "Invoke passes its two arguments to the function")
    out := 0
    Assert.Equal(ComCall(0, h.Ptr, "Ptr", 0, "Ptr*", &out), 0, "QueryInterface answers S_OK")
    Assert.Equal(out, h.Ptr, "and gives the handler itself")
    Assert.Equal(ComCall(1, h.Ptr), 1, "AddRef returns a count of 1")
}

AFailingFunctionDoesNotFailTheCaller() {
    h := ComHandler(BoomInvoke)
    Assert.Equal(ComCall(3, h.Ptr, "Ptr", 0, "Ptr", 0), 0, "the caller gets S_OK, the error is logged")
}

LoaderIsNotAvailableWithoutTheFile() {
    Assert.True(!WebView2Loader.Probe(A_ScriptDir "\no_such_folder\WebView2Loader.dll"), "no file, no loader")
    Assert.True(!WebView2Loader.Probe(""), "no path")
}

LoaderIsAvailableExactlyWhenTheSetupFileIsThere() {
    dll := HelpPages.WebView2Dll()
    Assert.True(InStr(dll, "\assets\bin\WebView2Loader.dll") > 0, dll)
    Assert.Equal(WebView2Loader.Probe(dll), FileExist(dll) != "", "the file loads and the runtime is found")
}

ViewerWithoutLoaderFailsOnce() {
    reasons := []
    v := WebView2Viewer(0, "", (reason) => reasons.Push(reason))
    v.Start()
    Assert.Equal(reasons.Length, 1, "one failure is reported")
    Assert.True(v.failed, "the viewer knows it failed")
    v.Start()
    v.Navigate(HelpPages.Resolve("", "en")["path"])
    v.Resize(0, 0, 100, 100)
    v.Close()
    Assert.Equal(reasons.Length, 1, "a second start or any call reports nothing more")
}

TestRun.Case("a COM handler answers QueryInterface, AddRef and Invoke through a vtable", HandlerIsAComObject)
TestRun.Case("a failing function does not fail the COM caller", AFailingFunctionDoesNotFailTheCaller)
TestRun.Case("the loader is not available without its file", LoaderIsNotAvailableWithoutTheFile)
TestRun.Case("the loader is available exactly when the setup file is there", LoaderIsAvailableExactlyWhenTheSetupFileIsThere)
TestRun.Case("a viewer that cannot start reports the failure once", ViewerWithoutLoaderFailsOnce)

TestRun.Finish()
