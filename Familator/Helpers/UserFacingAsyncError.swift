import Foundation

/// Maps async failures to user-visible alert text, omitting routine cancellation.
enum UserFacingAsyncError {
    /// Returns text for an alert, or `nil` when the error should be ignored (task / request cancellation).
    static func alertMessage(from error: Error) -> String? {
        if error is CancellationError {
            return nil
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return nil
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
            return nil
        }
        return error.localizedDescription
    }
}
