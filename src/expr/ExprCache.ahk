#Requires AutoHotkey v2.0

; Cache from key to value with an upper limit; when it is full, the oldest entry is removed (first in,
; first out; reading does not renew an entry). Used by Expr for the parse results (WI-37 task 4).
; The ring of keys is a fixed-size Array, because a Map does not keep the order of insertion.
class ExprCache {
    maxEntries := 2000
    hits := 0
    misses := 0

    _map := Map()
    _ring := []
    _head := 1
    _count := 0

    __New(maxEntries := 2000) {
        if (maxEntries < 1)
            maxEntries := 1
        this.maxEntries := maxEntries
        this._ring.Length := maxEntries
    }

    Count => this._count

    ; The value for key, or "" if there is none. Counts a hit or a miss.
    Get(key) {
        if (this._map.Has(key)) {
            this.hits += 1
            return this._map[key]
        }
        this.misses += 1
        return ""
    }

    Put(key, value) {
        if (this._map.Has(key)) {
            this._map[key] := value
            return
        }
        if (this._count >= this.maxEntries)
            this._map.Delete(this._ring[this._head])
        else
            this._count += 1
        this._ring[this._head] := key
        this._map[key] := value
        this._head := (this._head >= this.maxEntries) ? 1 : this._head + 1
    }

    Clear() {
        this._map := Map()
        this._ring := []
        this._ring.Length := this.maxEntries
        this._head := 1
        this._count := 0
        this.hits := 0
        this.misses := 0
    }
}
