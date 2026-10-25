import SpriteKit

enum SignalDiveKenneyVectorArt {
    struct Layer {
        let path: String
        let color: SKColor
    }

    // Direct CC0 vector fragments from Kenney Fish Pack 2.0.
    // Source:
    // https://github.com/MatteoMassaro/BubBlow/blob/5d7830ef6c7041787139cfa8b7cd6ae4d60a1a65/assets/sprites/kenney_fish-pack/Vector/fishPack_vector.svg
    // Upstream author: Kenney · CC0-1.0
    private static let variants: [[Layer]] = [
        [
            Layer(
                path: """
                M 456.95 439.2
                Q 456.8 439.2 456.6 439.2
                Q 447.5 439.35 440.95 442.1
                Q 434.1 445 434.1 449.15
                Q 434.1 453.25 440.95 456.15
                Q 447.5 458.95 456.6 459.05
                Q 456.8 459.05 456.95 459.05
                Q 453.3 448.85 456.95 439.2 Z
                """,
                color: SKColor(
                    red: 0.204,
                    green: 0.596,
                    blue: 0.859,
                    alpha: 1
                )
            ),
            Layer(
                path: """
                M 460.35 439.4
                Q 457.05 439.2 456.95 439.2
                Q 453.3 448.85 456.95 459.05
                Q 457.05 459.05 457.15 459.05
                Q 464 458.95 471.15 454.45
                Q 478.25 449.95 475.7 447.45
                Q 473.1 445 468.35 442.25
                Q 463.55 439.55 460.35 439.4
                M 465.9 446.8
                Q 466.35 446.35 466.95 446.35
                Q 467.6 446.35 468.05 446.8
                Q 468.5 447.25 468.5 447.85
                Q 468.5 448.45 468.05 448.9
                Q 467.6 449.35 466.95 449.35
                Q 466.35 449.35 465.9 448.9
                Q 465.45 448.45 465.45 447.85
                Q 465.45 447.25 465.9 446.8 Z
                """,
                color: SKColor(
                    red: 0.216,
                    green: 0.647,
                    blue: 0.933,
                    alpha: 1
                )
            )
        ],
        [
            Layer(
                path: """
                M 539.85 441.05
                Q 538.353125 441.5109375 536.95 442.1
                Q 534.513671875 443.1314453125 532.95 444.3
                Q 530.1 446.4759765625 530.1 449.15
                Q 530.1 451.6212890625 532.6 453.65
                Q 534.2287109375 454.9978515625 536.95 456.15
                Q 543.9 458.917578125 552.35 459.05
                Q 552.4693359375 459.0486328125 552.6 459.05
                Q 552.8 459.05 552.95 459.05
                Q 552.53046875 457.8779296875 552.2 456.7
                Q 547.201171875 457.07734375 542.45 456.05
                Q 542.1 456 541.9 455.75
                Q 541.7 455.55 541.65 455.2
                L 541.35 453.1
                Q 541.35 452.8 541.5 452.55
                Q 541.65 452.3 541.9 452.1
                Q 542.15 452 542.45 451.95
                Q 546.9322265625 452.1033203125 551.25 451.4
                Q 550.9673828125 448.3921875 551.35 445.4
                Q 551.7876953125 442.2732421875 552.95 439.2
                Q 545.4494140625 439.3177734375 539.85 441.05 Z
                """,
                color: SKColor(
                    red: 0.204,
                    green: 0.596,
                    blue: 0.859,
                    alpha: 1
                )
            ),
            Layer(
                path: """
                M 567.15 454.45
                Q 574.25 449.95 571.7 447.45
                Q 569.1 445 564.35 442.25
                Q 561.919921875 440.8830078125 559.9 440.15
                Q 557.9298828125 439.4740234375 556.35 439.4
                Q 553.05 439.2 552.95 439.2
                Q 551.7876953125 442.2732421875 551.35 445.4
                Q 550.9673828125 448.3921875 551.25 451.4
                Q 552.55234375 451.2306640625 553.85 450.95
                Q 554.1 450.85 554.4 451
                Q 554.7 451.15 554.95 451.4
                Q 555.05 451.65 555.05 451.95
                L 554.85 455.6
                Q 554.85 456 554.6 456.2
                Q 554.35 456.5 553.9 456.55
                Q 553.05078125 456.65078125 552.2 456.7
                Q 552.53046875 457.8779296875 552.95 459.05
                Q 553.05 459.05 553.15 459.05
                Q 560 458.95 567.15 454.45
                M 561.9 448.9
                Q 561.45 448.45 561.45 447.85
                Q 561.45 447.25 561.9 446.8
                Q 562.35 446.35 562.95 446.35
                Q 563.6 446.35 564.05 446.8
                Q 564.5 447.25 564.5 447.85
                Q 564.5 448.45 564.05 448.9
                Q 563.6 449.35 562.95 449.35
                Q 562.35 449.35 561.9 448.9 Z
                """,
                color: SKColor(
                    red: 0.216,
                    green: 0.647,
                    blue: 0.933,
                    alpha: 1
                )
            )
        ]
    ]

    static func makeNode(
        variant: Int
    ) -> SKNode? {
        let layers =
            variants[
                abs(variant) %
                variants.count
            ]

        let root = SKNode()

        for layer in layers {
            guard let path =
                    SVGPathParser.path(
                        from: layer.path
                    ) else {
                return nil
            }

            let shape =
                SKShapeNode(
                    path: path
                )

            shape.fillColor =
                layer.color
            shape.strokeColor =
                layer.color
                    .withAlphaComponent(
                        0.16
                    )
            shape.lineWidth = 0.6

            root.addChild(
                shape
            )
        }

        root.setScale(0.82)
        return root
    }

    private enum SVGPathParser {
        enum Token {
            case command(Character)
            case number(CGFloat)
        }

        static func path(
            from text: String
        ) -> CGPath? {
            let tokens =
                tokenize(text)

            guard !tokens.isEmpty else {
                return nil
            }

            let raw =
                CGMutablePath()

            var index = 0
            var command: Character?

            func hasNumber(
                _ offset: Int = 0
            ) -> Bool {
                guard index + offset <
                        tokens.count else {
                    return false
                }

                if case .number =
                    tokens[index + offset] {
                    return true
                }

                return false
            }

            func readNumber()
            -> CGFloat? {
                guard index <
                        tokens.count else {
                    return nil
                }

                guard case let
                        .number(value) =
                        tokens[index] else {
                    return nil
                }

                index += 1
                return value
            }

            while index < tokens.count {
                if case let
                        .command(value) =
                        tokens[index] {
                    command = value
                    index += 1

                    if value == "Z" ||
                        value == "z" {
                        raw.closeSubpath()
                        command = nil
                        continue
                    }
                }

                guard let current =
                        command else {
                    return nil
                }

                switch current {
                case "M":
                    guard let x =
                            readNumber(),
                          let y =
                            readNumber() else {
                        return nil
                    }

                    raw.move(
                        to: CGPoint(
                            x: x,
                            y: y
                        )
                    )

                    command = "L"

                case "L":
                    guard hasNumber(),
                          let x =
                            readNumber(),
                          let y =
                            readNumber() else {
                        command = nil
                        continue
                    }

                    raw.addLine(
                        to: CGPoint(
                            x: x,
                            y: y
                        )
                    )

                case "Q":
                    guard hasNumber(),
                          let cx =
                            readNumber(),
                          let cy =
                            readNumber(),
                          let x =
                            readNumber(),
                          let y =
                            readNumber() else {
                        command = nil
                        continue
                    }

                    raw.addQuadCurve(
                        to: CGPoint(
                            x: x,
                            y: y
                        ),
                        control: CGPoint(
                            x: cx,
                            y: cy
                        )
                    )

                default:
                    return nil
                }
            }

            let box =
                raw.boundingBox

            guard box.width > 0,
                  box.height > 0 else {
                return nil
            }

            var transform =
                CGAffineTransform(
                    translationX:
                        -box.midX,
                    y:
                        -box.midY
                )

            return raw.copy(
                using: &transform
            )
        }

        private static func tokenize(
            _ text: String
        ) -> [Token] {
            var output: [Token] = []
            var number = ""

            func flushNumber() {
                guard !number.isEmpty,
                      let value =
                        Double(number) else {
                    number = ""
                    return
                }

                output.append(
                    .number(
                        CGFloat(value)
                    )
                )
                number = ""
            }

            for scalar in
                text.unicodeScalars {
                let character =
                    Character(
                        String(scalar)
                    )

                if "MLQZmlqz"
                    .contains(character) {
                    flushNumber()
                    output.append(
                        .command(
                            character
                        )
                    )
                } else if
                    character.isNumber ||
                    character == "-" ||
                    character == "+" ||
                    character == "." ||
                    character == "e" ||
                    character == "E" {
                    number.append(
                        character
                    )
                } else {
                    flushNumber()
                }
            }

            flushNumber()
            return output
        }
    }
}
