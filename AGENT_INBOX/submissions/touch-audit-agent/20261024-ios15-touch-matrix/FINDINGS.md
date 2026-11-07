# Touch evidence reference

Repository main 501ef814a0a9bea41419fe2d9f48315371b30320, relevant root, legal form, tools, games, image viewer, materials manually audited. This is a targeted source audit, not a claim every file is checked.

Most important common issue was root particle simultaneous DragGesture in separate PR #64. In this submission, static code demonstrates remaining hazards: parent swipe over ScrollView, PTT cleanup omission, two board's drag-to-tap without movement threshold, Xiangqi inactive invisible hit area, repeated jump onChanged, tactical map 1pt minimum, viewer single/double gesture composition, two game control cancellation gaps, and decorative shape overlays. User's prior black box is not a pointer-event tracer and does not prove all of these occurred in a particular session.
