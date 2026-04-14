import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CopyButton: View {
    let prompt: PromptRecord
    let repository: PromptRepository
    @State private var didCopy = false

    var body: some View {
        Button {
            UIPasteboard.general.setItems(
                [[UTType.plainText.identifier: prompt.displayBody]],
                options: [
                    .localOnly: true,
                    .expirationDate: Date().addingTimeInterval(300),
                ]
            )
            repository.markPromptCopied(id: prompt.idValue)

            withAnimation(.easeOut(duration: 0.2)) {
                didCopy = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    didCopy = false
                }
            }
        } label: {
            Label(didCopy ? "Copied" : "Copy Prompt", systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("detail.copy")
    }
}
