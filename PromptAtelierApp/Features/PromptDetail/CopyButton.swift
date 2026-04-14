import SwiftUI
import UIKit
import WidgetKit

struct CopyButton: View {
    let prompt: PromptRecord
    let repository: PromptRepository
    @State private var didCopy = false

    var body: some View {
        Button {
            UIPasteboard.general.string = prompt.displayBody
            repository.markPromptCopied(id: prompt.idValue)
            WidgetCenter.shared.reloadAllTimelines()

            withAnimation(.easeOut(duration: 0.2)) {
                didCopy = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    didCopy = false
                }
            }
        } label: {
            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(prompt.displayBody.isEmpty)
        .accessibilityIdentifier("detail.copy")
    }
}
