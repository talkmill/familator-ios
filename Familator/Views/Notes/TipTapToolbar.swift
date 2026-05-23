import SwiftUI

struct TipTapToolbar: View {
    @ObservedObject var formattingState: TipTapFormattingState
    let commandSink: TipTapCommandSink
    let isEditable: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // Text formatting
                Group {
                    toolbarButton("bold", isActive: formattingState.isBold) {
                        commandSink.execute(command: .toggleBold)
                    }
                    toolbarButton("italic", isActive: formattingState.isItalic) {
                        commandSink.execute(command: .toggleItalic)
                    }
                    toolbarButton("underline", isActive: formattingState.isUnderline) {
                        commandSink.execute(command: .toggleUnderline)
                    }
                }

                Divider().frame(height: 24).padding(.horizontal, 4)

                // Headings
                Group {
                    headingButton(level: 1)
                    headingButton(level: 2)
                    headingButton(level: 3)
                }

                Divider().frame(height: 24).padding(.horizontal, 4)

                // Lists
                Group {
                    toolbarButton("list.bullet", isActive: formattingState.isBulletList) {
                        commandSink.execute(command: .toggleBulletList)
                    }
                    toolbarButton("list.number", isActive: formattingState.isOrderedList) {
                        commandSink.execute(command: .toggleOrderedList)
                    }
                }

                Divider().frame(height: 24).padding(.horizontal, 4)

                // Color
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 30, height: 30)
                    .disabled(!isEditable)

                // Font size
                fontSizeMenu

                Divider().frame(height: 24).padding(.horizontal, 4)

                // Table
                Group {
                    toolbarButton("tablecells", isActive: false) {
                        commandSink.execute(command: .insertTable)
                    }
                    toolbarButton("plus.rectangle", isActive: false) {
                        commandSink.execute(command: .addRowAfter)
                    }
                    toolbarButton("plus.rectangle.portrait", isActive: false) {
                        commandSink.execute(command: .addColumnAfter)
                    }
                    toolbarButton("trash", isActive: false) {
                        commandSink.execute(command: .deleteTable)
                    }
                }

                Divider().frame(height: 24).padding(.horizontal, 4)

                // Undo / Redo
                Group {
                    Button {
                        commandSink.execute(command: .undo)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!isEditable || !formattingState.canUndo)

                    Button {
                        commandSink.execute(command: .redo)
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!isEditable || !formattingState.canRedo)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toolbarButton(_ systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 32, height: 32)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .disabled(!isEditable)
    }

    private func headingButton(level: Int) -> some View {
        Button {
            if formattingState.headingLevel == level {
                commandSink.execute(command: .setParagraph)
            } else {
                commandSink.execute(command: .toggleHeading, args: ["level": level])
            }
        } label: {
            Text("H\(level)")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .background(formattingState.headingLevel == level ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
        }
        .disabled(!isEditable)
    }

    private var fontSizeMenu: some View {
        Menu {
            Button("Default") { commandSink.execute(command: .setFontSize) }
            Button("12px") { commandSink.execute(command: .setFontSize, args: ["fontSize": "12px"]) }
            Button("14px") { commandSink.execute(command: .setFontSize, args: ["fontSize": "14px"]) }
            Button("16px") { commandSink.execute(command: .setFontSize, args: ["fontSize": "16px"]) }
            Button("18px") { commandSink.execute(command: .setFontSize, args: ["fontSize": "18px"]) }
            Button("24px") { commandSink.execute(command: .setFontSize, args: ["fontSize": "24px"]) }
        } label: {
            Image(systemName: "textformat.size")
                .frame(width: 32, height: 32)
        }
        .disabled(!isEditable)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                if formattingState.color.isEmpty { return .black }
                return Color(UIColor(hex: formattingState.color) ?? .black)
            },
            set: { newColor in
                let uiColor = UIColor(newColor)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                commandSink.execute(command: .setColor, args: ["color": hex])
            }
        )
    }
}
