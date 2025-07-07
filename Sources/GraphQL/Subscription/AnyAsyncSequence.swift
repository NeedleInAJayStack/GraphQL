/// A type-erased AsyncSequence that always delivers an `any Sendable` type.
public struct AnyAsyncSequence: AsyncSequence {
    public typealias Element = (any Sendable)?

    @usableFromInline
    typealias AsyncIteratorNextCallback = () async throws -> (any Sendable)?

    @usableFromInline
    let makeAsyncIteratorCallback: @Sendable () -> AsyncIteratorNextCallback

    @inlinable
    init<AS: AsyncSequence>(_ base: AS) {
        makeAsyncIteratorCallback = {
            var iterator = base.makeAsyncIterator()
            return {
                try await iterator.next().map { $0 as (any Sendable) }
            }
        }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        let nextCallback: AsyncIteratorNextCallback

        @usableFromInline
        init(nextCallback: @escaping AsyncIteratorNextCallback) {
            self.nextCallback = nextCallback
        }

        @inlinable
        public func next() async throws -> Element? {
            try await nextCallback()
        }
    }

    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        .init(nextCallback: makeAsyncIteratorCallback())
    }
}
