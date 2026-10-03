# Arcade 2D Games V1

## Scope

This checkpoint adds three original, code-rendered 2D games to VeilLink's Game Hub. All three support a local deterministic opponent and the existing nearby encrypted-match flow. They reuse the current `VLGM1` event envelope, conversation outbox, reconnect handling and history reconstruction; they do not add a game server, database table, package or binary asset.

## 弧光炮战

弧光炮战 is a turn-based 2D artillery duel.

- Each turret begins with five health points. A near hit deals one point and a direct hit deals two.
- The active player selects an angle from 15–80 degrees and power from 30–100 percent. Wind is shown before firing and is derived from the match session ID plus turn number.
- Terrain, projectile integration, impact distance and damage are deterministic. A peer rebuilding the same accepted commands therefore obtains the same landing points, health and winner.
- Reducing an opponent to zero health wins. If the 24-turn cap is reached, remaining health decides the winner; equal health is a draw.
- The local bot searches a bounded angle/power grid and submits its choice through the same rule engine as a human command. It has no state-mutation shortcut.

Quick start: first watch the wind arrow, set roughly 45 degrees and high power, then use the prior landing marker to correct power in small steps. Angle changes reshape the arc; power is usually the easier fine adjustment.

## 光轨突围

光轨突围 is a turn-based 2D lane runner rather than a board game.

- The course has five lanes and 18 rounds. On a turn, choose left, straight or right; crossing the outer boundary is rejected.
- Red barriers remove one of three shield points. A ship that loses its last shield is eliminated immediately.
- Gold energy cores are collected only on a collision-free lane. If both ships survive all rounds, shield points decide first and collected energy breaks an equal-shield result; an equal total is a draw.
- Upcoming obstacles and energy lanes are deterministically generated from the session ID and round. This provides an arcade-like changing course while keeping both peers and offline replay synchronized.
- The local bot considers only legal adjacent lanes, strongly avoids barriers, prefers an energy pickup and then prefers the center lane. Every selected shift is revalidated by the game engine.

Quick start: read the nearest obstacle row before choosing a lane. Protecting shields matters more than collecting energy, because the final score weights each shield at 100 points while each core is one point.

## 磁轨冰球

磁轨冰球 is a turn-based 2D physics duel rather than a board game.

- Set a shot angle from 0–359 degrees and power from 10–100. In screen coordinates, 0 degrees points right and 90 degrees points down; the host attacks the right goal and the guest attacks the left.
- The puck advances on a fixed 120 Hz simulation step with friction, wall rebounds and a small magnetic bend. Field polarity is deterministically derived from the session ID and turn, so it is visible gameplay state rather than security randomness.
- The first player to score three goals wins. If neither reaches three goals within 20 turns, the higher score wins; an equal score is a draw.
- The local bot evaluates a bounded 5-degree by 5-power action grid. Every candidate and the selected move pass through the same `apply` legality gate used by human and nearby-peer commands.
- The same accepted command sequence reconstructs puck position, bounce count, goals and the winner identically for offline replay and nearby play.

Quick start: aim roughly toward the center of the opponent's goal with high power. After a miss, use the displayed magnetic polarity and prior puck path to correct the angle; bank shots are useful when the magnetic bend pulls a straight shot away from the goal mouth.

## Offline and nearby modes

Offline matches run entirely on device. The same state types and validation functions power nearby matches. For nearby play, invite/accept/move/resign packets travel through VeilLink's existing encrypted chat transport. State is reconstructed from accepted, ordered conversation events, so reconnect and app relaunch do not require a second game-state channel. Invalid range, wrong-player, duplicate-turn and post-finish actions do not mutate state.

The deterministic course, wind and magnetic polarity are gameplay state, not security randomness. None of the games changes VeilLink's encryption or trust boundary.

## Performance and UI

- All three battlefields are drawn with SwiftUI `Canvas`; there are no texture downloads or image-decoding stalls.
- Simulation and bot searches are bounded, and no persistent frame loop is required for the turn-based rules.
- Compact hardware uses fewer terrain samples and lower-cost impact rendering. The explicit Owner/God Mode full-visual override may still select the high-quality path.
- Motion follows the shared Reduce Motion / compact / full-quality policy. Accessibility labels expose health, shield, lane, round and wind information without relying on color alone.

## Open-source review and provenance

The implementation was informed by a review of these public MIT repositories on 2026-10-02:

1. [RJoshi141/Zoomies](https://github.com/RJoshi141/Zoomies) at `aeecbcff32b3fdb266d274d55d089b846239cfc4` — an iOS 2D endless runner using SpriteKit. The review informed only general presentation ideas such as readable obstacle/collectible contrast and a compact arcade status surface. Its README separately marks its artwork as unavailable for commercial reuse or redistribution, so none of its sprites, animation frames, sounds or other assets are present in VeilLink.
2. [zhijunsheng/connect4-swiftui-ios](https://github.com/zhijunsheng/connect4-swiftui-ios) at `b4fac71ce0a1d77899b0e98acecb475e88f1e98d` — a small SwiftUI game. The review informed only the architectural preference for a lightweight native SwiftUI surface.

No source code, rules text, graphics, audio, names or bundled resources were copied from either repository. VeilLink's artillery physics, light-trail rules, deterministic generators, bots, UI and tests are original implementations. No upstream repository is vendored, and this checkpoint adds zero third-party dependencies.

## Verification contract

`ArcadeGamesTests` covers:

- deterministic artillery simulation, wind/course generation and command replay;
- rejection of out-of-range, out-of-turn, boundary and post-finish actions without mutation;
- reachable artillery damage and a complete bot-decided winner;
- shield-depletion victory in the lane runner;
- deterministic fixed-step magnetic-hockey physics, legal bot output and three-goal termination;
- legal local-bot output;
- reconstruction of all three games from encoded nearby-chat records, compared with directly applied state;
- direct magnetic-hockey command replay compared step for step.

Simulator and deterministic reconstruction tests do not prove RF behavior, sustained thermals or gameplay performance on physical hardware. Nearby multiplayer and the iPhone 7 rendering path remain real-device validation gates.
