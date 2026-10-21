# Variables

## Variable formats

There are some defined variable formats:

Normal

The value can be a number or some text. If a mathematical operation is applied to a string containing a number, it will be automatically interpreted as a number

Date

The value contains a date. If the date is shown, e.g. in a message box, it will be converted to a readable form. For example: 4:55 PM Saturday, November 27, 2004

List

The value contains a list with some elements. Each element has keys. Those keys can either be numerical (comparable to an array) or they can be an arbitrary name.

You can add or access elements by using some specific actions. If the date is shown, e.g. in a message box, it will be converted to a readable form.

## Variable names

Variable names are not case sensitive (for example, *CurrentDate* is the same as *currentdate*). Variable names may be up to 253 characters long and may consist of letters, numbers and the following punctuation: # _ @ $

A variable name mustn’t start with the letters "A_", since those are built in variables.

## Global and local variables

**Local variables**

As local variable can have almost any name. As soon it is set, it is available in the current instance. An instance is one execution. As soon the instance ends, all local variables will be deleted.

**Static variables**

Static variables must begin with "Static_". For example: Static_MyVar. Those variables are available in the current flow in all instances. They are kept when the flow has ended, even after a reboot.

**Global variables**

Global variables must begin with "Global_". For example: Global_MyVar. Those variables are available in all flows and they are kept when the flow has ended, even after a reboot.

## Using variables

Variables can be used in almost every edit field in the settings. If a string is needed, a variable's content can be inserted by enclosing them into percent signs.

 ***Example:***

**Expression**

Expressions are used to perform one or more operations upon a series of variables, literal strings, and/or literal numbers. In other words, they may be used in order to do some calculations or to make some comparisons.

Variable names in an expression are not enclosed in percent signs. Numbers are allowed.

It is possible to make a double reference. If a variable is enclosed in percent signs within an expression (e.g. %Var%), whatever that variable contains is assumed to be the name or partial name of another variable.

***Examples:***

Following operands are supported:

## Built in variables

The following variables are built in and are read only.

**Special characters**

**Flow variables**

Some elements, especially loops and triggers may provide other read only variables. See in the description of each element.

 In contrast to other variables, the variables that are set by the actions are thread variables. So, if you separate the flow into two threads, the thread 1 will not access the variables of thread 2.

**Date and time**

**Operating system and user info**

**Directories**
