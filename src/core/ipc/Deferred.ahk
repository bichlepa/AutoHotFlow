#Requires AutoHotkey v2.0

; Marker returned by a cmd.* handler that answers later (WI-0012). The handler returns
; Deferred.Marker() at once and keeps the request; the answer is sent later with Peer.Reply(request, payload).
; The peer sends nothing when the handler returns this object. The handler then owes exactly one
; Reply, also on every failure path, or the sender ends with its own timeout.
;
;   handler: (msg) => (queue.Add(... Reply later ...), Deferred.Marker())
class Deferred {
    static instance := ""

    ; Returns the one shared marker object. Compare with `is Deferred`.
    static Marker() {
        if (!IsObject(this.instance))
            this.instance := Deferred()
        return this.instance
    }
}
