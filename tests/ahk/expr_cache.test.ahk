#Requires AutoHotkey v2.0
; Unit tests for the parse cache of the expression library (WI-0037 task 4, src/expr/ExprCache.ahk and Expr.Parse).
#Include lib\ExprCheck.ahk

Fresh() {
    Expr.cache.Clear()
}

CheckSameTextGivesTheSameResult() {
    Fresh()
    a := Expr.ParseExpression("x + 1")
    b := Expr.ParseExpression("x + 1")
    Assert.True(a == b, "the second call should return the cached Map")
    Assert.Equal(Expr.cache.hits, 1)
    Assert.Equal(Expr.cache.misses, 1)
    Assert.Equal(Expr.cache.Count, 1)
}

CheckKindsAreSeparate() {
    Fresh()
    e := Expr.ParseExpression("x := 1")
    s := Expr.ParseScript("x := 1")
    Assert.Equal(e["kind"], "expression")
    Assert.Equal(s["kind"], "script")
    Assert.Equal(e["ast"]["type"], "Assign")
    Assert.Equal(s["ast"]["type"], "Script")
    Assert.Equal(Expr.cache.Count, 2)
}

CheckCaseMatters() {
    Fresh()
    a := Expr.ParseExpression("X + 1")
    b := Expr.ParseExpression("x + 1")
    Assert.Equal(a["ast"]["left"]["name"], "X")
    Assert.Equal(b["ast"]["left"]["name"], "x")
    Assert.Equal(Expr.cache.Count, 2)
}

CheckErrorsAreCachedToo() {
    Fresh()
    a := Expr.ParseExpression("1 +")
    b := Expr.ParseExpression("1 +")
    Assert.True(a == b)
    Assert.Equal(a["ok"], 0)
}

CheckEmptyTextIsCached() {
    Fresh()
    a := Expr.ParseExpression("")
    b := Expr.ParseExpression("")
    Assert.True(a == b)
    Assert.Equal(a["ast"]["type"], "Empty")
}

CheckCacheCanBeSkipped() {
    Fresh()
    a := Expr.Parse("x + 1", "expression", false)
    b := Expr.Parse("x + 1", "expression", false)
    Assert.True(a != b, "without the cache every call parses again")
    Assert.Equal(Expr.cache.Count, 0)
    Assert.Equal(Expr.cache.hits + Expr.cache.misses, 0)
    Assert.Equal(ExprDump.Sexp(a["ast"]), ExprDump.Sexp(b["ast"]))
}

CheckOldestEntryIsRemoved() {
    c := ExprCache(3)
    c.Put("a", 1)
    c.Put("b", 2)
    c.Put("c", 3)
    Assert.Equal(c.Count, 3)
    c.Put("d", 4)
    Assert.Equal(c.Count, 3)
    Assert.Equal(c.Get("a"), "")
    Assert.Equal(c.Get("b"), 2)
    c.Put("e", 5)
    Assert.Equal(c.Get("b"), "")
    Assert.Equal(c.Get("c"), 3)
    Assert.Equal(c.Get("d"), 4)
    Assert.Equal(c.Get("e"), 5)
    c.Put("f", 6)
    c.Put("g", 7)
    c.Put("h", 8)
    Assert.Equal(c.Get("e"), "")
    Assert.Equal(c.Get("h"), 8)
    Assert.Equal(c.Count, 3)
}

CheckReadingDoesNotRenewAnEntry() {
    c := ExprCache(2)
    c.Put("a", 1)
    c.Put("b", 2)
    c.Get("a")
    c.Put("c", 3)
    Assert.Equal(c.Get("a"), "", "first in, first out")
    Assert.Equal(c.Get("b"), 2)
}

CheckPutOfAnExistingKeyReplacesTheValue() {
    c := ExprCache(2)
    c.Put("a", 1)
    c.Put("a", 9)
    Assert.Equal(c.Count, 1)
    Assert.Equal(c.Get("a"), 9)
    c.Put("b", 2)
    Assert.Equal(c.Count, 2)
}

CheckLimitOfOne() {
    c := ExprCache(1)
    c.Put("a", 1)
    c.Put("b", 2)
    Assert.Equal(c.Count, 1)
    Assert.Equal(c.Get("a"), "")
    Assert.Equal(c.Get("b"), 2)
    c2 := ExprCache(0)
    Assert.Equal(c2.maxEntries, 1)
}

CheckClear() {
    c := ExprCache(5)
    c.Put("a", 1)
    c.Get("a")
    c.Get("x")
    c.Clear()
    Assert.Equal(c.Count, 0)
    Assert.Equal(c.hits, 0)
    Assert.Equal(c.misses, 0)
    Assert.Equal(c.Get("a"), "")
    c.Put("b", 2)
    Assert.Equal(c.Get("b"), 2)
}

CheckDefaultLimitIs2000() {
    Fresh()
    Assert.Equal(Expr.cache.maxEntries, 2000)
    loop 2500
        Expr.ParseExpression("v" A_Index " + 1")
    Assert.Equal(Expr.cache.Count, 2000)
    ; the first 500 are gone, the last ones are still in
    before := Expr.cache.misses
    Expr.ParseExpression("v2500 + 1")
    Assert.Equal(Expr.cache.misses, before)
    Expr.ParseExpression("v1 + 1")
    Assert.Equal(Expr.cache.misses, before + 1)
}

CheckLongTextsAreNotCached() {
    Fresh()
    long := "x + " StrReplace(Format("{:25000}", ""), " ", "1")
    a := Expr.ParseExpression(long)
    Assert.Equal(Expr.cache.Count, 0)
    Assert.Equal(a["ok"], 1)
    ok := "x + " StrReplace(Format("{:100}", ""), " ", "1")
    Expr.ParseExpression(ok)
    Assert.Equal(Expr.cache.Count, 1)
}

CheckCachedTreeIsShared() {
    ; the evaluator reads the tree; it never changes it
    Fresh()
    a := Expr.ParseExpression("a.b + f(1, 2)")
    b := Expr.ParseExpression("a.b + f(1, 2)")
    Assert.True(a["ast"] == b["ast"])
}

CheckCacheIsFaster() {
    ; The measurement is tools-side (tests/ahk/helpers/expr_bench.ahk); this only guards the idea
    ; with a wide margin so that a loaded machine does not fail the test.
    Fresh()
    text := 'round(a.b * 2.5, 2) . " units"'
    t0 := A_TickCount
    loop 300
        Expr.Parse(text, "expression", false)
    uncached := A_TickCount - t0
    Expr.ParseExpression(text)
    t0 := A_TickCount
    loop 300
        Expr.ParseExpression(text)
    cached := A_TickCount - t0
    Assert.True(cached * 3 <= uncached || uncached < 15, "cached " cached " ms, uncached " uncached " ms")
}

TestRun.Init()

TestRun.Case("the same text gives the same result object", CheckSameTextGivesTheSameResult)
TestRun.Case("expression and script of the same text are cached apart", CheckKindsAreSeparate)
TestRun.Case("texts that differ in case are cached apart", CheckCaseMatters)
TestRun.Case("results with errors are cached", CheckErrorsAreCachedToo)
TestRun.Case("empty text is cached", CheckEmptyTextIsCached)
TestRun.Case("the cache can be skipped per call", CheckCacheCanBeSkipped)
TestRun.Case("the oldest entry is removed when the cache is full", CheckOldestEntryIsRemoved)
TestRun.Case("reading does not renew an entry", CheckReadingDoesNotRenewAnEntry)
TestRun.Case("putting an existing key replaces the value", CheckPutOfAnExistingKeyReplacesTheValue)
TestRun.Case("a limit of one entry", CheckLimitOfOne)
TestRun.Case("Clear empties the cache and the counters", CheckClear)
TestRun.Case("the default limit is 2000 entries", CheckDefaultLimitIs2000)
TestRun.Case("texts longer than 20000 characters are not cached", CheckLongTextsAreNotCached)
TestRun.Case("the cached tree is shared", CheckCachedTreeIsShared)
TestRun.Case("a cache hit is much faster than parsing", CheckCacheIsFaster)

TestRun.Finish()
