#if DEBUG
import SwiftUI

/// Dispara el self-check del generador de planes en el canvas de Xcode (no hay target de tests).
/// Si `GeneratePlanUseCase.selfCheck()` rompe un assert, el preview falla ruidoso.
#Preview("GeneratePlan · self-check") {
    Text(GeneratePlanUseCase.selfCheck())
        .font(.footnote)
        .padding()
}
#endif
