//
//  Copyright (c) 2020. Ben Pious
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

/**
 A Recording of changes to `Root`.
 
 You initialize an instance of this class by calling `MutationOf<MyType>()`.
 
 You can then write code to reference these types in the same way you would in any other circumstance,
 except that you must call `set(to: )` instead of using the normal `=` operator.
 
 For example, given:
 ```
 struct MyType {
     var v: MyChild
 }
 struct MyChild {
     var a: Int = 8
 }
 ```
 You can write:
 ```
 let recorder = MutationOf<MyType>()
 recorder.v.a.set(to: 10)
 ```
 
You could use this recorder to apply the changes to a real instance of `MyChild`:
 ```
 recorder.apply(to: realInstance)
 ```
 
 Or treat it as a predicate, and see if an existing instance matches:
 ```
 recorder.matches(target: realInstance)
 ```
 
 You can also access the individual recorded mutations through the `changes` property, and can introspect them using
 `has(prefix:)`, `has(suffix: andValue: )`, or use `==` to compare directly to a `PartialKeyPath`.
 
 As the goal of this class is to produce recordings that you can store and introspect, any recording value is
 required to conform to `Hashable`. This isn't an inherent limitation of this technique; but it makes it more
 useful for the typical purpose of storing the changes.
 */
@dynamicMemberLookup
public struct MutationOf<Root> {
    
    /**
     The list of changes currently made.
     */
    public var changes: [Mutation<Root>] {
        built.wrapped
    }
    
    /**
     Applies all the mutations to `target`.
     */
    public func apply(to target: inout Root) {
        for change in changes {
            change.setter(&target)
        }
    }
    
    /**
     Indicate if `target` has identical values for all the mutations in the callee.
     */
    public func matches(target: Root) -> Bool {
        changes.allSatisfy { (change) -> Bool in
            change.matches(target: target)
        }
    }
    
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Root, NextChild>
    ) -> Recorder<Root, Root, NextChild> {
        Recorder<Root, Root, NextChild>(
            built: built,
            path: Path<Root, NextChild>(
                fromRoot: member,
                untypedPath: [member]
            )
        )
    }
    
    private let built: ReferenceTo<[Mutation<Root>]> = ReferenceTo([])
    
}

/**
 Intermediate node in a recorded call.
 
 You use dynamic member lookup to interact with the recording. When you're ready to set a value, you use
 `set(to: )`.
 */
@dynamicMemberLookup
public struct Recorder<Root, Parent, Child> {
    
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Child, NextChild>
    ) -> Recorder<Root, Child, NextChild> {
        Recorder<Root, Child, NextChild>(
            built: built,
            path: Path<Root, NextChild>(
                fromRoot: path.fromRoot.appending(path: member),
                untypedPath: path.untypedPath + [member]
            )
        )
    }
    
    fileprivate init(built: ReferenceTo<[Mutation<Root>]>, path: Path<Root, Child>) {
        self.built = built
        self.path = path
    }
    
    fileprivate let built: ReferenceTo<[Mutation<Root>]>
    fileprivate var path: Path<Root, Child>
    
}

extension Recorder where Child: Hashable {
    
    /**
     Sets a node to the provided value.
     */
    public func set(to value: Child) {
        built.wrapped.append(
            Mutation(
                value: value,
                path: path.untypedPath,
                checker: { root in
                    root[keyPath: path.fromRoot] == value
                },
                setter: { (root) in
                    root[keyPath: path.fromRoot] = value
                }
            )
        )
    }
    
}

/**
 A mutation of `Root`.
 */
public final class Mutation<Root>: Hashable {
    
    public var path: AnyKeyPath {
        pathComponents.dropFirst().reduce(pathComponents[0]) { (path, next) in
            path.appending(path: next)!
        }
    }
    
    public let pathComponents: [AnyKeyPath]
    
    /**
     Applies the individual mutation to `target`.
     */
    public func apply(to target: inout Root) {
        setter(&target)
    }
    
    /**
     Indicates if the target's value for the keypath represented by a mutation is
     is the same as the value the mutation has.
     */
    public func matches(target: Root) -> Bool {
        checker(target)
    }
    
    /**
     Indicates if the callee has `prefix` as its prefix.
     */
    public func has<T>(prefix: PartialKeyPath<T>) -> Bool {
        let prefix: AnyKeyPath = prefix
        var partialPath = pathComponents[0]
        if partialPath == prefix {
            return true
        }
        for segment in pathComponents.dropFirst() {
            partialPath = prefix.appending(path: segment)!
            if partialPath == prefix {
                return true
            }
        }
        return false
    }
    
    /**
     Indicates if the callee has the suffix as its suffix, and it's value matches the provided test.
     */
    public func has<T>(suffix: AnyKeyPath,
                       andValue valueTest: ((T) -> Bool)? = nil) -> Bool {
        let suffix: AnyKeyPath = suffix
        var partialPath = pathComponents.last!
        if partialPath == suffix {
            return valueTest?(value as! T) ?? false
        }
        for segment in pathComponents.reversed().dropFirst() {
            partialPath = suffix.appending(path: segment)!
            if partialPath == suffix {
                return valueTest?(value as! T) ?? false
            }
        }
        return false
    }
    
    
    fileprivate init<Child>(value: Child,
                            path: [AnyKeyPath],
                            checker: @escaping (Root) -> Bool,
                            setter: @escaping (inout Root) -> ()) where Child: Hashable {
        self.isEqual = { rhs in
            path == rhs.pathComponents &&
                // The `as!` is safe because if path == rhs path, then the value of `rhs`
                // must be the same type as our own `value`.
                value == rhs.value as! Child
        }
        self.value = value
        self.hashWitness =  { value.hashValue }
        self.pathComponents = path
        self.setter = setter
        self.checker = checker
    }
    
    public static func == (lhs: Mutation<Root>, rhs: Mutation<Root>) -> Bool {
        lhs.isEqual(rhs)
    }
    
    public static func == (lhs: Mutation<Root>, rhs: PartialKeyPath<Root>) -> Bool {
        lhs.path == rhs
    }

    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pathComponents)
        hasher.combine(hashWitness())
    }
        
    fileprivate let isEqual: (Mutation<Root>) -> (Bool)
    fileprivate let value: Any
    fileprivate let hashWitness: () -> Int
    fileprivate let setter: (inout Root) -> ()
    fileprivate let checker: (Root) -> (Bool)
        
}

fileprivate struct Path<Root, C> {
    
    let fromRoot: WritableKeyPath<Root, C>
    let untypedPath: [AnyKeyPath]
    
}


@dynamicMemberLookup
fileprivate class ReferenceTo<T> {
    
    init(_ wrapped: T) {
        self.wrapped = wrapped
    }
    
    subscript<U>(dynamicMember member: WritableKeyPath<T, U>) -> U {
        get {
            wrapped[keyPath: member]
        }
        set {
            wrapped[keyPath: member] = newValue
        }
    }
    
    subscript<U>(dynamicMember member: KeyPath<T, U>) -> U {
        wrapped[keyPath: member]
    }
    
    var wrapped: T
    
}
