#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The HTTP functions of the package Default (WI-0122): a request through WinHTTP (the COM object WinHttpRequest.5.1 of
; Windows) with the options of v1 (method, headers, body, response to a variable or a file, proxy, user agent, codepage).
; The worker calls these functions; nothing here runs in the engine.
;
; Deadlines (no request waits without one, F-0190): the four WinHTTP timeouts (name resolution, connect, send, receive)
; are set on every request; the element has a job deadline (JobTimeoutMs). A request that is over its deadline ends with
; an exception, and the worker is ended with the element when the job is aborted.
;
; Content-MD5 (v1 computed it with its own library) is the MD5 of the body, computed by the Windows crypto API (advapi32).
class HttpOps {
    static CONNECT_MS := 10000       ; name resolution and connect
    static IO_MS := 60000            ; send and receive (per operation)

    ; A new WinHTTP request object. Throws ElementError when WinHTTP is not available.
    static Client() {
        try
            return ComObject("WinHttp.WinHttpRequest.5.1")
        catch
            throw ElementError(Lang("The HTTP client of Windows (WinHTTP) could not be started."))
    }

    ; The scheme of an URL: "http" or "https" only (v1 refused the others, HTTPRequest does not support '...').
    static CheckUrl(url) {
        if (!RegExMatch(url, "i)^https?://[^/\s]+"))
            throw ElementError(Lang("HTTP Request does not support this URL: '%1%'", url))
    }

    ; The bytes of a text in an encoding: "UTF-8" (the default), "UTF-16", a code page number or "CPnnnn". An unknown name
    ; ends with an exception. Returns a Buffer without the terminating null character.
    static Encode(text, encoding) {
        try {
            size := StrPut(text, encoding)          ; the bytes needed, with the terminating null character
            buf := Buffer(size, 0)
            StrPut(text, buf, encoding)
        } catch {
            throw ElementError(Lang("The codepage '%1%' is not known.", encoding))
        }
        kind := StrLower(encoding)
        terminator := (kind = "utf-16") ? 2 : (kind = "utf-32") ? 4 : 1
        return HttpOps._Slice(buf, Max(size - terminator, 0))
    }

    ; A copy of the first n bytes of a buffer.
    static _Slice(buf, n) {
        out := Buffer(n)
        if (n > 0)
            DllCall("RtlMoveMemory", "ptr", out.Ptr, "ptr", buf.Ptr, "uptr", n)
        return out
    }

    ; The bytes of a SAFEARRAY of VT_UI1 (the body that WinHTTP returns), copied into a Buffer. Returns an empty Buffer
    ; for an empty body or a value that is not an array.
    static FromSafeArray(value) {
        ptr := (value is ComValue) ? ComObjValue(value) : 0
        if (ptr = 0)
            return Buffer(0)
        n := NumGet(ptr, 24, "uint")                  ; rgsabound[0].cElements
        data := NumGet(ptr, 16, "ptr")                ; pvData
        return HttpOps._Copy(data, n)
    }

    ; A copy of n bytes at address data.
    static _Copy(data, n) {
        out := Buffer(n)
        if (n > 0 && data != 0)
            DllCall("RtlMoveMemory", "ptr", out.Ptr, "ptr", data, "uptr", n)
        return out
    }

    ; A SAFEARRAY of VT_UI1 with the bytes of buf, wrapped for the Send method of WinHTTP. The caller frees it with
    ; HttpOps.FreeSafeArray after the call.
    static ToSafeArray(buf) {
        n := buf.Size
        psa := DllCall("oleaut32\SafeArrayCreateVector", "uint", 17, "int", 0, "uint", n, "ptr")
        if (psa = 0)
            throw ElementError(Lang("The request body could not be prepared."))
        if (n > 0) {
            data := 0
            DllCall("oleaut32\SafeArrayAccessData", "ptr", psa, "ptr*", &data)
            DllCall("RtlMoveMemory", "ptr", data, "ptr", buf.Ptr, "uptr", n)
            DllCall("oleaut32\SafeArrayUnaccessData", "ptr", psa)
        }
        return {value: ComValue(0x2011, psa), psa: psa}
    }

    static FreeSafeArray(wrapped) {
        if (IsObject(wrapped) && wrapped.psa)
            DllCall("oleaut32\SafeArrayDestroy", "ptr", wrapped.psa)
    }

    ; The Content-MD5 header value of a body: the MD5 of the bytes, base64 (RFC 1864). Uses the Windows crypto API.
    static ContentMd5(buf) {
        hProv := 0, hHash := 0
        if (!DllCall("advapi32\CryptAcquireContextW", "ptr*", &hProv, "ptr", 0, "ptr", 0, "uint", 1, "uint", 0xF0000000))
            throw ElementError(Lang("The Content MD5 could not be calculated."))
        try {
            if (!DllCall("advapi32\CryptCreateHash", "ptr", hProv, "uint", 0x8003, "ptr", 0, "uint", 0, "ptr*", &hHash))
                throw ElementError(Lang("The Content MD5 could not be calculated."))
            if (buf.Size > 0 && !DllCall("advapi32\CryptHashData", "ptr", hHash, "ptr", buf.Ptr, "uint", buf.Size, "uint", 0))
                throw ElementError(Lang("The Content MD5 could not be calculated."))
            digest := Buffer(16, 0), len := 16
            if (!DllCall("advapi32\CryptGetHashParam", "ptr", hHash, "uint", 2, "ptr", digest.Ptr, "uint*", &len, "uint", 0))
                throw ElementError(Lang("The Content MD5 could not be calculated."))
            chars := 0
            DllCall("crypt32\CryptBinaryToStringW", "ptr", digest.Ptr, "uint", 16, "uint", 0x40000001, "ptr", 0, "uint*", &chars)
            out := Buffer(chars * 2, 0)
            DllCall("crypt32\CryptBinaryToStringW", "ptr", digest.Ptr, "uint", 16, "uint", 0x40000001, "ptr", out.Ptr, "uint*", &chars)
            return StrGet(out, "UTF-16")
        } finally {
            if (hHash)
                DllCall("advapi32\CryptDestroyHash", "ptr", hHash)
            DllCall("advapi32\CryptReleaseContext", "ptr", hProv, "uint", 0)
        }
    }

    ; The headers of a request text: one "Name: value" (or "Name:value") per line, as v1 wrote them. Returns an Array of
    ; [name, value]; empty lines are skipped, a line without a colon is refused.
    static ParseHeaders(text) {
        headers := []
        loop parse text, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "")
                continue
            pos := InStr(line, ":")
            if (!pos)
                throw ElementError(Lang("The request header '%1%' has no colon.", line))
            headers.Push([Trim(SubStr(line, 1, pos - 1)), Trim(SubStr(line, pos + 1))])
        }
        return headers
    }
}
