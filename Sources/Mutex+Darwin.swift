//
//  Mutex.swift
//  swift-mutex
//
//  Created by Simon Whitty on 07/09/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-mutex
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#if canImport(Darwin)

import struct os.os_unfair_lock_t
import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock
import func os.os_unfair_lock_trylock

// Backports the Swift 6 type Mutex<Value> to all Darwin platforms
struct Mutex<Value: ~Copyable>: ~Copyable {
    let storage: Storage<Value>

    init(_ initialValue: consuming sending Value) {
        self.storage = Storage(initialValue)
    }

    borrowing func withLock<Result, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        storage.lock()
        defer { storage.unlock() }
        return try body(&storage.value)
    }

    borrowing func withLockIfAvailable<Result, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result? {
        guard storage.tryLock() else { return nil }
        defer { storage.unlock() }
        return try body(&storage.value)
    }
}

extension Mutex: @unchecked Sendable where Value: ~Copyable { }

final class Storage<Value: ~Copyable> {
    private let _lock: os_unfair_lock_t
    var value: Value

    init(_ initialValue: consuming Value) {
        self._lock = .allocate(capacity: 1)
        self._lock.initialize(to: os_unfair_lock())
        self.value = initialValue
    }

    func lock() {
        os_unfair_lock_lock(_lock)
    }

    func unlock() {
        os_unfair_lock_unlock(_lock)
    }

    func tryLock() -> Bool {
        os_unfair_lock_trylock(_lock)
    }

    deinit {
        self._lock.deinitialize(count: 1)
        self._lock.deallocate()
    }
}

#endif
