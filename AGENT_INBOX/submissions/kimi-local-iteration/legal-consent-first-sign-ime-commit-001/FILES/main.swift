import Foundation

// Behavioural harness for legal-consent-first-sign-ime-commit-001.
//
// Drives the REAL production decision functions (VeilLegalConsentRequirements.canSign and
// VeilLegalAcknowledgmentInput.publishableText from VeilLink/Core/LegalConsentInputPolicy.swift)
// through a simulated UITextField editingChanged event stream, and models the SwiftUI button
// disabled semantics that turned the IME race into a dead first tap.

private var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition {
        print("PASS  \(label)")
    } else {
        failures += 1
        print("FAIL  \(label)")
    }
}

/// One .editingChanged event, faithful to UIKit: while an IME composition is in flight the
/// field's `text` holds the intermediate composition and `markedTextRange != nil`.
struct EditingEvent {
    let text: String
    let hasMarkedText: Bool
}

/// View state semantics: @State acknowledgment + the three confirmations.
final class GateState {
    var acknowledgment = ""
    var confirmsPermissions = true
    var confirmsRisk = true
    var confirmsVersionRule = true

    var canSign: Bool {
        VeilLegalConsentRequirements.canSign(
            confirmsPermissions: confirmsPermissions,
            confirmsRisk: confirmsRisk,
            confirmsVersionRule: confirmsVersionRule,
            acknowledgment: acknowledgment
        )
    }
    var confirmationsReady: Bool {
        confirmsPermissions && confirmsRisk && confirmsVersionRule
    }
}

enum PolicyVersion { case preFix, postFix }

/// The Coordinator.textChanged wiring, pre-fix (publish everything) vs post-fix (filtered).
func publish(_ event: EditingEvent, into state: GateState, policy: PolicyVersion) {
    switch policy {
    case .preFix:
        state.acknowledgment = event.text
    case .postFix:
        if let text = VeilLegalAcknowledgmentInput.publishableText(
            fieldText: event.text, hasMarkedText: event.hasMarkedText
        ) {
            state.acknowledgment = text
        }
    }
}

/// Models resignFirstResponder: UIKit commits the pending composition, replacing field text
/// with the final committed string and firing one final .editingChanged (hasMarkedText == false).
func commitComposition(finalText: String, into state: GateState, policy: PolicyVersion) {
    publish(EditingEvent(text: finalText, hasMarkedText: false), into: state, policy: policy)
}

/// A tap on the primary button. Returns the produced error message, or nil if signing proceeded.
@discardableResult
func tapSign(_ state: GateState, policy: PolicyVersion, compositionOpen: Bool, finalComposition: String) -> String? {
    // SwiftUI .disabled swallows the tap before the action can run.
    let buttonEnabled = (policy == .preFix) ? state.canSign : state.confirmationsReady
    guard buttonEnabled else { return "__tap_swallowed__" }
    // sign(): commit any in-flight IME composition, then evaluate.
    if compositionOpen {
        commitComposition(finalText: finalComposition, into: state, policy: policy)
    }
    guard state.canSign else { return "请完成三项确认，并准确输入签署确认语。" }
    return nil
}

// MARK: - Scenario A: reproduce the bug with the pre-fix wiring

print("== Scenario A: pre-fix wiring, pinyin candidate bar open at sign tap ==")
do {
    let state = GateState()
    // User types the whole acknowledgement as one uncommitted pinyin composition.
    let stream: [EditingEvent] = [
        .init(text: "w", hasMarkedText: true),
        .init(text: "woyiyuedu", hasMarkedText: true),
        .init(text: "woyiyuedu bingtongyi", hasMarkedText: true),
    ]
    stream.forEach { publish($0, into: state, policy: .preFix) }
    check(!state.canSign, "A1 pre-fix: polluted state disables the gate")
    let first = tapSign(state, policy: .preFix, compositionOpen: true, finalComposition: "我已阅读并同意")
    check(first == "__tap_swallowed__", "A2 pre-fix: FIRST tap on sign is silently swallowed")
    // The user finishes the IME selection (space/candidate key) — UIKit commits the composition
    // and fires a final editingChanged with the committed text.
    commitComposition(finalText: "我已阅读并同意", into: state, policy: .preFix)
    let second = tapSign(state, policy: .preFix, compositionOpen: false, finalComposition: "")
    check(second == nil, "A3 pre-fix: only AFTER committing the composition does a tap succeed (matches report)")
}

// MARK: - Scenario B: post-fix wiring — one tap, composition open

print("== Scenario B: post-fix wiring, same event stream ==")
do {
    let state = GateState()
    let stream: [EditingEvent] = [
        .init(text: "w", hasMarkedText: true),
        .init(text: "woyiyuedu", hasMarkedText: true),
        .init(text: "woyiyuedu bingtongyi", hasMarkedText: true),
    ]
    stream.forEach { publish($0, into: state, policy: .postFix) }
    check(state.acknowledgment == "", "B1 post-fix: marked composition never pollutes state")
    let first = tapSign(state, policy: .postFix, compositionOpen: true, finalComposition: "我已阅读并同意")
    check(first == nil, "B2 post-fix: FIRST tap signs successfully (bug fixed)")
}

// MARK: - Scenario C: post-fix with fully committed text, no composition open

print("== Scenario C: post-fix, plain committed typing (regression) ==")
do {
    let state = GateState()
    publish(.init(text: "我已阅读并同意", hasMarkedText: false), into: state, policy: .postFix)
    check(state.canSign, "C1 committed text signs fine")
    let result = tapSign(state, policy: .postFix, compositionOpen: false, finalComposition: "")
    check(result == nil, "C2 sign proceeds on first tap")
}

// MARK: - Scenario D: gate still closed without confirmations or wrong text

print("== Scenario D: invariants unchanged ==")
do {
    let state = GateState()
    state.confirmsRisk = false
    publish(.init(text: "我已阅读并同意", hasMarkedText: false), into: state, policy: .postFix)
    check(!state.canSign, "D1 missing confirmation still blocks signing")
    let s2 = GateState()
    publish(.init(text: "我同意", hasMarkedText: false), into: s2, policy: .postFix)
    let err = tapSign(s2, policy: .postFix, compositionOpen: false, finalComposition: "")
    check(err == "请完成三项确认，并准确输入签署确认语。", "D2 wrong acknowledgement still rejected with error")
}

// MARK: - Scenario E: unit matrix for publishableText

print("== Scenario E: publishableText unit matrix ==")
check(VeilLegalAcknowledgmentInput.publishableText(fieldText: "woyiyuedu", hasMarkedText: true) == nil,
      "E1 marked composition -> nil (not publishable)")
check(VeilLegalAcknowledgmentInput.publishableText(fieldText: "我已阅读并同意", hasMarkedText: false) == "我已阅读并同意",
      "E2 committed text -> published verbatim")
check(VeilLegalAcknowledgmentInput.publishableText(fieldText: nil, hasMarkedText: false) == "",
      "E3 nil field text -> normalised to empty string")

if failures > 0 {
    print("HARNESS_RESULT: FAIL (\(failures))")
    exit(1)
}
print("HARNESS_RESULT: PASS (all scenarios)")
