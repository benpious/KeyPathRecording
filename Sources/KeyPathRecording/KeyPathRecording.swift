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
 See the documentation of `RecordingOf` for details about this type.
 */
public typealias Predicate<Root> = RecordingOf<Root, PropertyPredicate<Root>>

/**
 See the documentation of `RecordingOf` for details about this type.
 */
public typealias MutationOf<Root> = RecordingOf<Root, Mutation<Root>>

/**
 A Recording of changes to `Root`.
 
 It's best to use the typealiases `Predicate<Root>` and `MutationOf<Root>` to interact with this
 type. You initialize them with `Predicate<Root>()` and `MutationOf<Root>` respectively. There are also versions
 which take closures letting you perform the muations inline.
  
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
 let recorder = MutationOf<MyType> { recording in
    recording.v.a.set(to: 10)
 }
 ```
 
You could use this recorder to apply the changes to a real instance of `MyChild`:
 ```
 recorder.apply(to: realInstance)
 ```
 
 You can also access the individual recorded mutations through the `changes` property, and can introspect them using
 `has(prefix:)`, `has(suffix: andValue: )`, or use `==` to compare directly to a `PartialKeyPath`.
 
 Meanwhile, the `Predicate` version lets you test if the recording matches a target:
 ```
 recorder.matches(target: realInstance)
 ```
  
 As the goal of this library is to produce recordings that you can store and introspect, any recording value is
 required to conform to `Hashable`. But this isn't an inherent limitation of this technique; you can make your own `Record` type and appropriate extensions which do not have this limitation.
 */
@dynamicMemberLookup
public struct RecordingOf<Root, Record> {
    
    /**
     Initializer.
     */
    public init() {
        
    }
    
    /**
     Initializer.
     */
    public init(changes: (inout RecordingOf<Root, Record>) -> ()) {
        changes(&self)
    }
    
    /**
     The list of changes currently made.
     */
    public var changes: [Record] {
        built.wrapped
    }
        
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Root, NextChild>
    ) -> Recorder<Root, Root, NextChild, Record> {
        Recorder<Root, Root, NextChild, Record>(
            built: built,
            path: Path<Root, NextChild>(
                fromRoot: member,
                untypedPath: [member]
            )
        )
    }
    
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Root, NextChild?>
    ) -> Recorder<Root, Root, NextChild?, Record> {
        Recorder<Root, Root, NextChild?, Record>(
            built: built,
            path: Path<Root, NextChild?>(
                fromRoot: member,
                untypedPath: [member]
            )
        )
    }

    private let built: ReferenceTo<[Record]> = ReferenceTo([])
    
}

public extension Recorder where Child: Hashable, Record == Mutation<Root> {
    
    /**
     Sets a node to the provided value.
     */
    func set(to value: Child) {
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

public extension RecordingOf where Record == Mutation<Root> {
    
    /**
     Applies all the mutations to `target`.
     */
    func apply(to target: inout Root) {
        for change in changes {
            change.setter(&target)
        }
    }

}

public extension RecordingOf where Record == PropertyPredicate<Root> {
    
    func matches(target: Root) -> Bool {
        changes.allSatisfy { (predicate) -> Bool in
            predicate.test(target)
        }
    }
    
}

public extension Recorder where Record == PropertyPredicate<Root>, Child: Hashable {
    
    func isEqual(to value: Child) {
        let predicate = PropertyPredicate<Root>(
            value: value,
            path: path.fromRoot,
            technique: .equality,
            test: { (root: Root) -> Bool in
                root[keyPath: path.fromRoot] == value
            }
        )
        built.wrapped.append(
            predicate
        )
    }
        
}

public extension Recorder where Record == PropertyPredicate<Root>, Child: Hashable, Child: Comparable {
    
    func isLess(than value: Child) {
        let predicate = PropertyPredicate<Root>(
            value: value,
            path: path.fromRoot,
            technique: .lessThanComparision,
            test: { (root: Root) -> Bool in
                root[keyPath: path.fromRoot] < value
            }
        )
        built.wrapped.append(
            predicate
        )
    }
    
    func isGreater(than value: Child) {
        let predicate = PropertyPredicate<Root>(
            value: value,
            path: path.fromRoot,
            technique: .greaterThanComparision,
            test: { (root: Root) -> Bool in
                root[keyPath: path.fromRoot] > value
            }
        )
        built.wrapped.append(
            predicate
        )
    }
        
}

/**
 Intermediate node in a recorded call.
 
 You use dynamic member lookup to interact with the recording. When you're ready to set a value, you use
 `set(to: )`.
 */
@dynamicMemberLookup
public struct Recorder<Root, Parent, Child, Record> {
    
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Child, NextChild>
    ) -> Recorder<Root, Child, NextChild, Record> {
        Recorder<Root, Child, NextChild, Record>(
            built: built,
            path: Path<Root, NextChild>(
                fromRoot: path.fromRoot.appending(path: member),
                untypedPath: path.untypedPath + [member]
            )
        )
    }
    
    public subscript<NextChild>(
        dynamicMember member: WritableKeyPath<Child, NextChild?>
    ) -> Recorder<Root, Child, NextChild?, Record> {
        Recorder<Root, Child, NextChild?, Record>(
            built: built,
            path: Path<Root, NextChild?>(
                fromRoot: path.fromRoot.appending(path: member),
                untypedPath: path.untypedPath + [member]
            )
        )
    }
    
    fileprivate init(built: ReferenceTo<[Record]>, path: Path<Root, Child>) {
        self.built = built
        self.path = path
    }
    
    fileprivate let built: ReferenceTo<[Record]>
    fileprivate var path: Path<Root, Child>
    
}

public struct PropertyPredicate<Root>: Hashable {
    
    enum Comparision: Hashable {
        
        // TODO: turn this into something extensible for custom comparisons
        // probably a bitmask
        
        case equality
        case lessThanComparision
        case greaterThanComparision
        case notEqual
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(hashWitness())
        hasher.combine(technique)
    }
    
    public static func == (lhs: PropertyPredicate<Root>, rhs: PropertyPredicate<Root>) -> Bool {
        lhs.isEqual(rhs)
    }
    
    fileprivate let test: (Root) -> Bool
    fileprivate let path: AnyKeyPath
    fileprivate let value: Any
    fileprivate let isEqual: (PropertyPredicate) -> (Bool)
    fileprivate let hashWitness: () -> Int
    fileprivate let technique: Comparision
    
    fileprivate init<T>(value: T,
                        path: PartialKeyPath<Root>,
                        technique: Comparision,
                        test: @escaping (Root) -> Bool) where T: Hashable {
        self.technique = technique
        self.path = path
        self.test = test
        self.value = value
        isEqual = { rhs in
            path == rhs.path &&
                technique == rhs.technique &&
                value == (rhs.value as! T)
        }
        hashWitness = { value.hashValue }
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

/**
 Do not conform to or interact with this protocol.
 
 This protocol is an implementation detail.
 
 Swift generics are not covariant, so `KeyPath<T?, U>` isn't the same
 as `KeyPath<T, U>`, and thus `Recorder<T?>` doesn't have any of the dynamic lookup
 features that `Recorder<T>` would have.
 */
public protocol KeyPathRecordingOptional {
    
    associatedtype Wrapped
    
    subscript<U>(__unwrap path: WritableKeyPath<Wrapped, U>) -> U? { get set }
    
    subscript<U>(__unsafe_unwrap path: WritableKeyPath<Wrapped, U>) -> U  { get set }
    
}

extension Optional: KeyPathRecordingOptional {
    
    @available(swift, deprecated: 0.1, message: "An imp")
    public subscript<U>(__unwrap path: WritableKeyPath<Wrapped, U>) -> U? {
        get {
            if let wrapped = self {
                return wrapped[keyPath: path]
            } else {
                return nil
            }
        }
        set {
            if var wrapped = self,
               let newValue = newValue {
                wrapped[keyPath: path] = newValue
                self = .some(wrapped)
            }
        }
    }
    
    @available(swift, deprecated: 0.1)
    public subscript<U>(__unsafe_unwrap path: WritableKeyPath<Wrapped, U>) -> U {
        @available(*, unavailable)
        get {
            fatalError()
        }
        set {
            if var wrapped = self {
                wrapped[keyPath: path] = newValue
                self = .some(wrapped)
            }
        }
    }
    
}

public extension Recorder where Child: KeyPathRecordingOptional {
    
    subscript<Next>(dynamicMember member: WritableKeyPath<Child.Wrapped, Next>) -> Recorder<Root, Child, Next?, Record> {
        Recorder<Root, Child, Next?, Record>(
            built: built,
            path: Path<Root, Next?>(
                fromRoot: path.fromRoot.appending(path: \Child.[__unwrap: member]),
                untypedPath: path.untypedPath + [member]
            )
        )
    }
    
    subscript<Next>(dynamicMember member: WritableKeyPath<Child.Wrapped, Next?>) -> Recorder<Root, Child, Next?, Record> {
        Recorder<Root, Child, Next?, Record>(
            built: built,
            path: Path<Root, Next?>(
                fromRoot: path.fromRoot.appending(path: \Child.[__unsafe_unwrap: member]),
                untypedPath: path.untypedPath + [member]
            )
        )
    }
    
}

