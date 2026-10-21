#Requires AutoHotkey v2.0

; The WebView2 loader DLL and the runtime (WI-0115, E0099): is WebView2 available? The loader is WebView2Loader.dll (x64)
; of the NuGet package Microsoft.Web.WebView2, fetched by tools/fetch_webview2_loader.py into assets\bin (shipping it is
; S0009). The runtime is the Evergreen WebView2 Runtime of Windows (Edge). "Available" means: the DLL loads, its exports
; are there, and the runtime reports its version. The answer is cached for the process (the choice of the viewer asks it
; for every page).
;
; The exports used: CreateCoreWebView2EnvironmentWithOptions, GetAvailableCoreWebView2BrowserVersionString (WebView2.h
; 1.0.2739.15). Nothing here touches a window.
class WebView2Loader {
    static _available := ""     ; "" not asked yet, else true or false (for the default DLL only)
    static _lib := 0           ; the module of the DLL that Available loaded

    ; True when the DLL at dll loads and the runtime is installed. Asks once per process for the default DLL (the
    ; argument of the first call is kept); Probe does the work and is not cached.
    static Available(dll) {
        if (WebView2Loader._available = "")
            WebView2Loader._available := WebView2Loader.Probe(dll)
        return WebView2Loader._available
    }

    ; The module handle of the loaded DLL (0 when Probe has not loaded it, e.g. no DLL).
    static Module() => WebView2Loader._lib

    ; The check itself: the file exists, LoadLibrary works, both exports are there and the runtime version is known.
    static Probe(dll) {
        if (dll = "" || !FileExist(dll))
            return false
        hLib := 0
        try hLib := DllCall("LoadLibrary", "Str", dll, "Ptr")
        catch
            return false
        if (!hLib)
            return false
        if (!DllCall("GetProcAddress", "Ptr", hLib, "AStr", "CreateCoreWebView2EnvironmentWithOptions", "Ptr")
            || !DllCall("GetProcAddress", "Ptr", hLib, "AStr", "GetAvailableCoreWebView2BrowserVersionString", "Ptr"))
            return false
        if (WebView2Loader.RuntimeVersion(hLib) = "")
            return false
        WebView2Loader._lib := hLib
        return true
    }

    ; The version string of the installed runtime, "" when there is none (no exception).
    static RuntimeVersion(hLib) {
        pVer := DllCall("GetProcAddress", "Ptr", hLib, "AStr", "GetAvailableCoreWebView2BrowserVersionString", "Ptr")
        if (!pVer)
            return ""
        verPtr := 0
        try hr := DllCall(pVer, "Ptr", 0, "Ptr*", &verPtr, "Int")
        catch
            return ""
        version := ""
        if (verPtr) {
            if ((hr & 0xFFFFFFFF) < 0x80000000)
                version := StrGet(verPtr, "UTF-16")
            DllCall("ole32\CoTaskMemFree", "Ptr", verPtr)
        }
        return version
    }

    ; The export of the loaded DLL (0 when there is none).
    static Proc(name) {
        if (!WebView2Loader._lib)
            return 0
        return DllCall("GetProcAddress", "Ptr", WebView2Loader._lib, "AStr", name, "Ptr")
    }
}
