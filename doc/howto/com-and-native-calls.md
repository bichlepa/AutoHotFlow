# How-to AHK v2: COM and native calls (WebView2)

Entries from the WebView2 viewer (WI-0115, E0099): COM interfaces through `ComCall`, our own COM handlers built with
`CallbackCreate`, and `DllCall` into the loader DLL. Code: `src/help/ComHandler.ahk`, `src/help/WebView2Loader.ahk`,
`src/help/WebView2Viewer.ahk`. The vtable indexes come from `WebView2.h` (in the NuGet package, not in the repository).

### A function stored in a property is called with its owner as first argument

- **Problem:** A COM handler keeps its function in a property (`h.fn`). Calling `h.fn(a, b)` passes `h` as the first argument, so the function gets the wrong values and throws; the error was swallowed by the callback's `try`, and the test that counted the calls saw nothing.
- **Wrong:** `try h.fn(a, b)`
- **Right:** `fn := h.fn` and then `fn(a, b)`. The same holds for every hook kept in a property (`onLink`, `onFailed`).
- **Status:** verified (found by `tests/ahk/help_webview2.test.ahk`, fixed in `ComHandler._Invoke`)
- **Source:** `src/help/ComHandler.ahk`; see also the entry in `objects-maps-arrays.md`.

### COM method index = position in the header + 3

- **Problem:** `ComCall` takes the zero-based index in the vtable, which includes `QueryInterface`, `AddRef` and `Release`. The header lists the methods of one interface without them.
- **Wrong:** using the position in the `.h` file as the index (off by three).
- **Right:** index = position + 3 (e.g. `ICoreWebView2::Navigate` is position 2, index 5; `ICoreWebView2Controller::Close` is position 21, index 24). List the method names of an interface from `WebView2.h` with a short script that reads the interface block (the property accessors have a `/* [propget] */` comment before `virtual`, so a pattern on `virtual HRESULT` misses them; match `STDMETHODCALLTYPE <name>(` instead).
- **Status:** verified (the spike and the viewer call Navigate, get_Source, put_Bounds, Close, get_CoreWebView2 and the event registrations with these indexes)
- **Source:** `docs/lib/ComCall.htm` ("zero-based index ... the first three methods are always QueryInterface (0), AddRef (1) and Release (2)")

### Pointers handed to a callback belong to the caller until we AddRef them

- **Problem:** The environment and the controller arrive as the result of a completion handler. After the handler returns, the runtime may free them. The spike used the controller 8 seconds later to close it and crashed with an invalid memory access (a dialog of AHK).
- **Wrong:** `gCtrl := ctrl` and use it later.
- **Right:** `ComCall(1, ctrl)` (AddRef) before keeping it, and `ComCall(2, ctrl)` (Release) after the last use (`WebView2Viewer.Close`). The pointers that a getter returns through an out parameter (`Ptr*`) are already AddRef'ed for us; they are not released in this code (leak of a few objects per viewer start, known).
- **Status:** verified (spike: the crash without AddRef, a clean close with it)
- **Source:** `temp/wv2-spike/spike.ahk` (not committed), `src/help/WebView2Viewer.ahk`

### A string from COM is freed with CoTaskMemFree

- **Problem:** Getters such as `get_Source`, `get_Uri` and `GetAvailableCoreWebView2BrowserVersionString` return an `LPWSTR` allocated by the runtime.
- **Wrong:** `StrGet` only, and the pointer is lost (a leak per call).
- **Right:** `text := StrGet(p, "UTF-16")` and then `DllCall("ole32\CoTaskMemFree", "Ptr", p)`, in that order. Helper: `WebView2Viewer._Text`.
- **Status:** assumed (the calls return the right text; no leak measurement)
- **Source:** `src/help/WebView2Viewer.ahk`, `src/help/WebView2Loader.ahk`

### HRESULT and pointer parameters of a callback: mask the upper bits

- **Problem:** A callback parameter of a 32-bit type (HRESULT) arrives as a 64-bit value whose upper bits can contain garbage.
- **Wrong:** `if (hr < 0)` on the raw parameter.
- **Right:** `hr & 0xFFFFFFFF`, then `>= 0x80000000` for failure (`WebView2Viewer.Failed`). Pointers are not masked.
- **Status:** verified (read in the `CallbackCreate` documentation: "the upper bits of the value might contain garbage")
- **Source:** `docs/lib/CallbackCreate.htm`

### A handler object is a vtable of four callbacks plus one pointer

- **Problem:** A COM completion or event handler is a pointer to a pointer to a vtable: `QueryInterface`, `AddRef`, `Release` and the method (`Invoke`).
- **Wrong:** a `Buffer` with the callbacks in the wrong order, or a `Buffer` that goes out of scope (the callee calls a freed address).
- **Right:** a `Buffer` of `4 * A_PtrSize` for the vtable (`CallbackCreate` addresses with `"F"`, parameter counts 3, 1, 1, 3), a `Buffer(A_PtrSize)` whose first pointer is the vtable, and both kept alive (`ComHandler._alive`). `QueryInterface` returns the object for every IID (the handler implements nothing else). The callbacks are not freed; a few per viewer start.
- **Status:** verified (the events and the completion handlers of the viewer run); the answer to every IID is assumed to be enough (the runtime never asked for another interface in the runs)
- **Source:** `src/help/ComHandler.ahk`

### Global and function names are one name

- **Problem:** A global variable `LOG` and a function `Log` are the same name in AHK v2 (case-insensitive). The editor reports "This Func 'Log' cannot be used as an output variable".
- **Wrong:** `global LOG := A_ScriptDir "\spike.log"` next to `Log(text)`.
- **Right:** a name of its own (`LOG_FILE`).
- **Status:** verified (the editor diagnostic and the spike)
- **Source:** `temp/wv2-spike/spike.ahk` (not committed)

### A path for WebView2 must be a full path

- **Problem:** A navigation to `file:///...\..\assets\help\en\Welcome.html` stayed on `about:blank` (the source was still `about:blank` after 2 seconds).
- **Wrong:** a relative path with `..` in the file URL.
- **Right:** the full path from `GetFullPathNameW` (the spike), or a path that has no `..`, which is the case in the program (the path comes from `A_LineFile`).
- **Status:** assumed (two spike runs; the full path was the only change to the navigation between them)
- **Source:** `temp/wv2-spike/spike.ahk` (not committed)

### The WebView2 user data folder is created by the runtime

- **Problem:** The help role must not create folders (`DirCreate` is file I/O, rule `file-io`), but the user data folder must exist for the environment.
- **Wrong:** `DirCreate` in the role.
- **Right:** pass the folder path; the runtime creates it (the spike's folder appeared without `DirCreate` in the viewer check).
- **Status:** verified (`temp/wv2-spike/userdata` appeared in the viewer check run)
- **Source:** `src/help/WebView2Viewer.ahk`

### The event registration token is an Int64 out parameter

- **Problem:** `add_SourceChanged` and `add_NavigationStarting` take an `EventRegistrationToken*` (64 bit).
- **Wrong:** `"Ptr*"` or `"Int*"` for the token.
- **Right:** `"Int64*"` with a variable (`&tok`); the token is not needed (the handlers stay for the process).
- **Status:** verified (the location changes reached the window through `add_SourceChanged`)
- **Source:** `src/help/WebView2Viewer.ahk`
