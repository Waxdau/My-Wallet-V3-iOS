import Blockchain
import SwiftUI

public struct FinancialPromotionDisclaimerView: View {

    @BlockchainApp var app

    @State private var text: String?

    @State private var isDismissEnabled: Bool = true
    @State private var isDismissed: Bool = false
    @State private var isSynchronized: Bool = false

    @Binding var display: Bool

    public init(display: Binding<Bool> = .constant(false)) { _display = display }

    public var body: some View {
        Group {
            if isDismissed {
                EmptyView()
            } else if isSynchronized, text.isNil {
                EmptyView()
            } else if let text {
                VStack {
                    if isDismissEnabled {
                        IconButton(
                            icon: .closeFilled,
                            action: {
                                $app.post(value: true, of: blockchain.ux.finproms.disclaimer.is.dismissed)
                            }
                        )
                        .frame(alignment: .trailing)
                    }
                    Text(rich: text)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                        .typography(.micro)
                        .foregroundColor(Color(red: 0.4, green: 0.44, blue: 0.52))
                        .onTapGesture {
                            $app.post(event: blockchain.ux.finproms.disclaimer.tap)
                        }
                }
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .bindings(managing: { state in isSynchronized = state.isSynchronized }) {
            subscribe($text, to: blockchain.ux.finproms.disclaimer.text)
            subscribe($isDismissed, to: blockchain.ux.finproms.disclaimer.is.dismissed)
            subscribe($isDismissEnabled, to: blockchain.ux.finproms.disclaimer.is.dismiss.enabled)
        }
        .onChange(of: isSynchronized) { _ in
            display = text.isNotNilOrEmpty
        }
    }
}

public struct FinancialPromotionApprovalView: View {

    @BlockchainApp var app

    @State private var text: String?
    @State private var isSynchronized: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if isSynchronized, text.isNil {
                EmptyView()
            } else if let text {
                Text(rich: text)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .typography(.micro)
                    .foregroundColor(Color(red: 0.4, green: 0.44, blue: 0.52))
                    .onTapGesture {
                        $app.post(event: blockchain.ux.finproms.approval.tap)
                    }
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .bindings(managing: { state in isSynchronized = state.isSynchronized }) {
            subscribe($text, to: blockchain.ux.finproms.approval.text)
        }
    }
}
