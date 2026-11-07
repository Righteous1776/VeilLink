# Risks

- Cleanup must never target the provider URL returned by Apple's Files picker. Only the app-owned UUID lease path may be removed.
- A broad recursive temporary-directory cleanup is prohibited. The existing ownership predicate and 24-hour age gate are mandatory.
- Immediate sheet dismissal cleanup must be idempotent because `AppModel.restoreBackup` already removes the same lease in `defer`.
- Cold-launch cleanup is best-effort and must never delay startup or turn a cleanup failure into an app-launch failure.
- Camera captures are not necessarily stored under the Files staging root, so their existing single-file fallback deletion must remain.
- This Inbox proposal has not been applied to product source or validated on a physical Files provider.
