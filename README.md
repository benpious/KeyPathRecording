# KeyPathRecording

## Motivation

This library lets you record and store mutations to a struct or object for later application, or to use as a predicate to match other instances.

`KeyPath` and its associated classes don't have any introspection built in; you can append, and you can check for equality, but that's it.  This library lets you check whether a recorded path has a prefix or suffix. 

## Using the Library

You install this library as a dependency using Swift Package Manager. 

The entrypoint of the library is call `MutationOf<MyType>()` to create an instance of `MutationOf` that you can use. 

You can then write code to reference these types in the same way you would in any other circumstance,
except that you must call `set(to: )` instead of using the normal `=` operator.

There's more detailed documentation in the source files. 
