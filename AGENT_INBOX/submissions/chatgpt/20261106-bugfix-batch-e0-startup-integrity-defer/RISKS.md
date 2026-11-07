# E0 risks / overlaps
- This improves possible first-frame blocking, NOT all cold-start costs. DatabaseStore init still migrates and cleans old transfer metadata synchronously. AppModel also creates many other controllers.
- Running full PRAGMA off-main does not prevent DatabaseStore's single SQL queue from blocking other DB calls while the query is active; user-visible chat operations must be tested under large DB.
- Swift 6 sendability checks may reject cross-task capture of DatabaseStore or weak MainActor self; integration Xcode compile required. The repository already dispatches DatabaseStore reads via global GCD queue, but that is not proof of this exact hunk compiling.
- Pending PR #138 touches startup diagnostics/performance and could overlap behavior. Governor chooses sequencing, not this lane.
- Do not delay identity/key verification or acceptance gates. Database health is `unchecked` until verification completes, never mislabeled `ok`.
- No main write, build, sign, release, workflow dispatch or merge.
- Real device and Apple SDK NOT_RUN; not production accepted.
