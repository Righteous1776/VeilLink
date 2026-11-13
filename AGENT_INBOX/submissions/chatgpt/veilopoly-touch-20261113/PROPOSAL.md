# Veilopoly tactile P0/P1 scope
- P0 idle blank/same-tile toggle to clear selection, animation tap skip remains.
- P0 skip 0.4s debounce with 0.6s confirmation at right edge, suppress later confirmation within 1 second; Reduce Motion opacity-only; ACK gate untouched.
- P0 auction +/- B01 original 44pt touch targets, four -50/-10/+10/+50 buttons, 0.5s long press at 10Hz, slider to min(cash, property price*2), 22pt bid display, light/error haptics, no auto-submit. Engine validation unchanged.
- P1 destructive semantic action style: red outline, preserve LazyVGrid and original ordering.
- NumericInput change only .sheet host to .popover; do not change keypad internals.
- P2 existing PanelWorkspace is already title-handle-only draggable, with ScrollView independent; no patch needed. Camera pinch/pan needs isolated Apple iOS15 touch/ACK acceptance before integration; never add recognizers without guarding animation/panel state.
- Engine/AI/Net, RenderCommandAckGate and Astra B01 canonical assets explicitly excluded.
