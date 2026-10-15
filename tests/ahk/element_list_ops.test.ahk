#Requires AutoHotkey v2.0
; Unit tests for src/elements/Default/lib/ListOps.ahk (WI-0053): the list operations without an engine. The elements
; (flows, parameters, variables) are covered by tests/integration/test_core_b_lists.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\lib\ListOps.ahk

; A list from the pairs key, value, key, value, ... (keys are normalized as the variable model does).
L(pairs*) {
    m := ListOps.NewList()
    i := 1
    while (i < pairs.Length) {
        m[ListOps.NormKey(pairs[i])] := pairs[i + 1]
        i += 2
    }
    return m
}

; The list as a text "key=value;..." in the order of the Map (Integer keys ascending, then texts).
S(m) {
    out := ""
    for key, item in m
        out .= (out = "" ? "" : ";") key "=" (IsObject(item) ? "<obj>" : item)
    return out
}

Case1() {
    m := L(1, "a", 2, "b", 4, "c", "k", "z", "1.5", "f")
    ListOps.Shuffle(m)
    Assert.Equal(m.Count, 5)
    Assert.Equal(m["k"], "z")
    Assert.True(m.Has(1) && m.Has(2) && m.Has(3) && m.Has(4) && !m.Has("1.5"))
    got := [m[1], m[2], m[3], m[4]]
    sorted := ""
    for want in ["a", "b", "c", "f"] {
        for v in got {
            if (v = want)
                sorted .= want
        }
    }
    Assert.Equal(sorted, "abcf")
}

Case2() {
    m := L(1, "a", 2, "b", 3, "c")
    ListOps.Shuffle(m, (lo, hi) => lo)              ; always the first: swaps i with 1
    Assert.Equal(S(m), "1=b;2=c;3=a")
    m := L(1, "a", 2, "b", 3, "c")
    ListOps.Shuffle(m, (lo, hi) => hi)              ; always the last: nothing moves
    Assert.Equal(S(m), "1=a;2=b;3=c")
}

Case3() {
    m := L()
    ListOps.Shuffle(m)
    Assert.Equal(m.Count, 0)
    m := L(5, "x")
    ListOps.Shuffle(m)
    Assert.Equal(S(m), "1=x")
}

TestRun.Init()

TestRun.Case("NormKey: decimal texts become Integers, other texts stay", () => (
    Assert.Equal(ListOps.NormKey("01"), 1), Assert.Equal(ListOps.NormKey("-2"), -2)
    , Assert.Equal(ListOps.NormKey("1.5"), "1.5"), Assert.Equal(ListOps.NormKey("a"), "a")
    , Assert.Equal(ListOps.NormKey(3), 3)))

TestRun.Case("Info: empty list", () => (
    Assert.Equal(ListOps.Info(L(), "minIndex"), ""), Assert.Equal(ListOps.Info(L(), "maxIndex"), "")
    , Assert.Equal(ListOps.Info(L(), "length"), 0), Assert.Equal(ListOps.Info(L(), "count"), 0)))

TestRun.Case("Info: a list with gaps and text keys", () => (
    m := L(2, "a", 5, "b", "k", "c", -1, "d")
    , Assert.Equal(ListOps.Info(m, "MinIndex"), -1), Assert.Equal(ListOps.Info(m, "maxIndex"), 5)
    , Assert.Equal(ListOps.Info(m, "length"), 5), Assert.Equal(ListOps.Info(m, "count"), 4)))

TestRun.Case("Info: only negative keys have length 0", () => Assert.Equal(ListOps.Info(L(-3, "x"), "length"), 0))

TestRun.Case("Info: an unknown information is an error", () => Assert.Throws(() => ListOps.Info(L(), "size"), ElementError))

TestRun.Case("Add Last appends after the highest positive key", () => (
    m := L(1, "a", 3, "c"), ListOps.Add(m, ["d", "e"], "Last"), Assert.Equal(S(m), "1=a;3=c;4=d;5=e")))

TestRun.Case("Add Last to an empty list starts at 1", () => (
    m := L(), ListOps.Add(m, ["x"], "Last"), Assert.Equal(S(m), "1=x")))

TestRun.Case("Add First moves the others up and keeps the order of several values", () => (
    m := L(1, "a", 2, "b"), ListOps.Add(m, ["x", "y"], "First"), Assert.Equal(S(m), "1=x;2=y;3=a;4=b")))

TestRun.Case("Add Specified Insert moves the members at that position and above", () => (
    m := L(1, "a", 2, "b", 4, "d"), ListOps.Add(m, ["x"], "Specified", "2", "Insert"), Assert.Equal(S(m), "1=a;2=x;3=b;5=d")))

TestRun.Case("Add Specified Overwrite replaces the value", () => (
    m := L(1, "a", 2, "b"), ListOps.Add(m, ["x"], "Specified", 2, "Overwrite"), Assert.Equal(S(m), "1=a;2=x")))

TestRun.Case("Add Specified several values at a position", () => (
    m := L(1, "a", 2, "b"), ListOps.Add(m, ["x", "y"], "Specified", 2, "Insert"), Assert.Equal(S(m), "1=a;2=x;3=y;4=b")
    , m := L(1, "a", 2, "b", 3, "c"), ListOps.Add(m, ["x", "y"], "Specified", 2, "Overwrite"), Assert.Equal(S(m), "1=a;2=x;3=y")))

TestRun.Case("Add Specified with a key name assigns it (and replaces the value of the key)", () => (
    m := L(1, "a"), ListOps.Add(m, ["x"], "Specified", "Name"), ListOps.Add(m, ["y"], "Specified", "name"), Assert.Equal(S(m), "1=a;Name=y")))

TestRun.Case("Add Specified: text that looks like a number is the Integer key", () => (
    m := L(1, "a"), ListOps.Add(m, ["x"], "Specified", "07", "Overwrite"), Assert.Equal(S(m), "1=a;7=x"), Assert.True(m.Has(7))))

TestRun.Case("Add Specified: several values need an Integer position", () => (
    m := L(), Assert.Throws(() => ListOps.Add(m, ["x", "y"], "Specified", "key"), ElementError)))

TestRun.Case("Add Specified: an empty position is an error", () => (
    m := L(), Assert.Throws(() => ListOps.Add(m, ["x"], "Specified", ""), ElementError)))

TestRun.Case("Add: a nested list is kept as a value", () => (
    m := L(), ListOps.Add(m, [L(1, "in")], "Last"), Assert.True(m[1] is Map), Assert.Equal(m[1][1], "in")))

TestRun.Case("Split: delimiters, empty fields, no delimiter", () => (
    Assert.Equal(S(ListOps.Split("a,b;c", ",;")), "1=a;2=b;3=c"), Assert.Equal(ListOps.Split("a,,b", ",").Length, 3)
    , Assert.Equal(ListOps.Split("a b", "")[1], "a b"), Assert.Equal(ListOps.Split("", "`n").Length, 0)))

TestRun.Case("Delete Decrement closes the gap", () => (
    m := L(1, "a", 2, "b", 3, "c", "k", "z"), v := ListOps.Delete(m, "Specified", 2, "Decrement", "l")
    , Assert.Equal(v, "b"), Assert.Equal(S(m), "1=a;2=c;k=z")))

TestRun.Case("Delete KeepGap leaves the others", () => (
    m := L(1, "a", 2, "b", 3, "c"), v := ListOps.Delete(m, "First", "", "KeepGap", "l")
    , Assert.Equal(v, "a"), Assert.Equal(S(m), "2=b;3=c")))

TestRun.Case("Delete Last and First look at the Integer keys only", () => (
    m := L(2, "a", 7, "b", "k", "z"), Assert.Equal(ListOps.Delete(m, "Last", "", "Decrement", "l"), "b")
    , Assert.Equal(S(m), "2=a;k=z"), Assert.Equal(ListOps.Delete(m, "First", "", "Decrement", "l"), "a"), Assert.Equal(S(m), "k=z")))

TestRun.Case("Delete: no Integer key, a missing key, an empty position are errors", () => (
    Assert.Throws(() => ListOps.Delete(L("k", "z"), "First", "", "Decrement", "l"), ElementError)
    , Assert.Throws(() => ListOps.Delete(L(), "Last", "", "Decrement", "l"), ElementError)
    , Assert.Throws(() => ListOps.Delete(L(1, "a"), "Specified", 2, "Decrement", "l"), ElementError)
    , Assert.Throws(() => ListOps.Delete(L(1, "a"), "Specified", "", "Decrement", "l"), ElementError)))

TestRun.Case("Delete Specified with a text key does not move anything", () => (
    m := L(1, "a", "k", "z"), Assert.Equal(ListOps.Delete(m, "Specified", "K", "Decrement", "l"), "z"), Assert.Equal(S(m), "1=a")))

TestRun.Case("KeyOfValue: numbers as numbers, texts without case, the first match, objects never", () => (
    m := L(1, "Apple", 2, "1.0", 3, "x", "k", "1", 5, L(1, "1"))
    , Assert.Equal(ListOps.KeyOfValue(m, "apple"), 1), Assert.Equal(ListOps.KeyOfValue(m, 1), 2)
    , Assert.Equal(ListOps.KeyOfValue(m, "1"), 2), Assert.True(ListOps.KeyOfValue(m, "nothing") == ListOps.NONE)
    , Assert.True(ListOps.KeyOfValue(L(1, ""), "") = 1)))

TestRun.Case("HasKey: '1' and 1 are one key, key names ignore case", () => (
    m := L(1, "a", "Name", "b"), Assert.True(ListOps.HasKey(m, "1")), Assert.True(ListOps.HasKey(m, 1))
    , Assert.True(ListOps.HasKey(m, "name")), Assert.True(!ListOps.HasKey(m, 2))))

TestRun.Case("Shuffle: the same values with the keys 1..n, other keys stay", Case1)

TestRun.Case("Shuffle: the random function decides the order (Fisher-Yates)", Case2)

TestRun.Case("Shuffle: an empty list and one member", Case3)

TestRun.Case("EnumValue: the default index of v1 becomes the enum text", () => (
    Assert.Equal(ListOps.EnumValue(2, ["Key", "Content"]), "Content"), Assert.Equal(ListOps.EnumValue("Key", ["Key", "Content"]), "Key")
    , Assert.Equal(ListOps.EnumValue(3, ["Key", "Content"]), 3)))

TestRun.Finish()
