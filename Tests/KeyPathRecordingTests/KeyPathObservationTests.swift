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

import XCTest
@testable import KeyPathRecording

final class PathKeyTests: XCTestCase {
    func test_various() {
        struct S {
            var v: V
        }
        struct V {
            var a: Int = 8
            var z: C = C()
        }
        let r = MutationOf<S>()
        r.v.a.set(to: 9)
        r.v.z.set(to: C())
        let apps = r.changes
        var s = S(v: V())
        let app = apps[0]
        XCTAssertTrue(app == app)
        app.apply(to: &s)
        XCTAssertTrue(app.path == \S.v.a)
        XCTAssertTrue(app.pathComponents.contains(\V.a))
        XCTAssertTrue(app.has(suffix: \V.a) { value in
            value == 9
        })
        XCTAssertTrue(app.has(prefix: \S.v))
    }

}

fileprivate class C: Hashable {
    
    static func == (lhs: C, rhs: C) -> Bool {
        lhs.a == rhs.a
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(a)
    }
    
    
    var a = 7
    
}