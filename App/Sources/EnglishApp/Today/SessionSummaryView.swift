import SwiftUI

struct SessionSummaryView: View {
    let reviewedCount: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Bugün \(reviewedCount) item tekrarladın")
                .font(.title2.bold())
            Button("Tamam", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
