private func wrapRetriable<T>(_ request: @escaping (() -> Observable<T>),
                                delay: DispatchTimeInterval,
                                retryWhen canRetry: @escaping ((T) throws -> Bool)) -> Observable<T> {
    Observable<T>.create { (s) -> Disposable in
        let subscription = request().subscribe(s)
        return Disposables.create {
            subscription.dispose()
        }
    }.map { v in
        if try canRetry(v) { throw ZPCashierError.processing }
        return v
        
    }.retry { (observableError) -> Observable<Int> in
        return observableError.enumerated().flatMap { (_, error) -> Observable<Int> in
            guard let cashierError = error as? ZPCashierError,
                  cashierError == .processing else {
                return Observable.error(error)
            }
            return Observable.timer(delay, scheduler: SerialDispatchQueueScheduler(qos: .background))
        }
    }
}
