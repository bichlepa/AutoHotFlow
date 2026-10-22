# Get from list

The action **Get from list** writes one value of a list to a variable. The list is not changed.

## Settings

### Output variable name

The variable that receives the value.

### Input list

The list, as the name of a variable that holds it (or an expression that gives a list).

### Key or position

**First integer position** takes the value with the lowest integer key (usually key 1).

**Last integer position** takes the value with the highest integer key.

**Random integer position** takes the value of a random integer key of the list.

**Following position or key** takes the value of the key in the field below. A key can be a number or a text.

If the list has no integer key, the first, last and random choices end with an exception. A key that the list does not have ends the action with an exception too.

## Remarks

Version 1 took a random number between the lowest and the highest key, which gave an empty value if that key was missing. Version 2 takes one of the keys that the list has (MIGRATION M-0109).
