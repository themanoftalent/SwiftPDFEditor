//
//  ToolbarView.swift
//  SwiftPDFEditor
//
//  Created by Akif CIFTCI on 29.04.2025.
//

import SwiftUI

struct ToolbarView: View {
    @Binding var currentTool: DrawingTool
    @Binding var color: Color
    @Binding var lineWidth: CGFloat
    @Binding var shapeType: ShapeType
    
    var body: some View {
        HStack(spacing: 12) {
            // Drawing Tools
            ToolButton(icon: "pencil", tool: .pen)
            ToolButton(icon: "highlighter", tool: .highlighter)
            ToolButton(icon: "textbox", tool: .text)
            
            // Shape Tools
            Menu {
                Picker("Shape", selection: $shapeType) {
                    Label("Rectangle", systemImage: "rectangle").tag(ShapeType.rectangle)
                    Label("Circle", systemImage: "circle").tag(ShapeType.circle)
                }
            } label: {
                ToolButton(icon: "square.on.square", tool: .shape)
            }
            
            ToolButton(icon: "eraser", tool: .eraser)
            
            Divider().frame(height: 20)
            
            // Color Picker
            ColorPicker("", selection: $color)
                .labelsHidden()
                .frame(width: 30)
            
            // Line Width
            Slider(value: $lineWidth, in: 1...20, step: 1)
                .frame(width: 100)
            
            Text("\(Int(lineWidth))px")
                .frame(width: 40, alignment: .trailing)
        }
        .padding(8)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func ToolButton(icon: String, tool: DrawingTool) -> some View {
        Button {
            currentTool = tool
        } label: {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(currentTool == tool ? .accentColor : .primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(toolDescription(tool))
    }
    
    private func toolDescription(_ tool: DrawingTool) -> String {
        switch tool {
        case .pen: return "Pen (P)"
        case .highlighter: return "Highlighter (H)"
        case .text: return "Text (T)"
        case .shape: return "Shape (S)"
        case .eraser: return "Eraser (E)"
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
