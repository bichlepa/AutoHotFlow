"""The identity of an element in the tests (E0045, WI-0047).

A flow element names its package (`package`) and its class (`class`); the registry, the worker jobs
(`cmd.worker.run`) and the logs use the qualified ID `<package>.<class>`. The product elements are in the package
`Default` (src/elements/Default), the test elements (`Action_Test*`) in the package `Test` (tests/elements/Test), which
only the test entries include.

The helpers take a class as the tests write it: `"Pkg.Class"` names the package, a plain test class (`Action_Test*`)
is in `Test`, any other plain class in `Default`.
"""

DEFAULT_PACKAGE = "Default"
TEST_PACKAGE = "Test"


def split(cls):
    """(package, class) of a class as the tests write it."""
    if "." in cls:
        package, name = cls.split(".", 1)
        return package, name
    if cls.lower().startswith("action_test"):
        return TEST_PACKAGE, cls
    return DEFAULT_PACKAGE, cls


def qid(cls):
    """The qualified ID `<package>.<class>`."""
    return "%s.%s" % split(cls)
