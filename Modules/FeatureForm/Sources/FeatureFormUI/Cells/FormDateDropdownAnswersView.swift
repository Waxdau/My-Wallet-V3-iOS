// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainComponentLibrary
import FeatureFormDomain
import Localization
import SwiftUI

struct FormDateDropdownAnswersView: View {

    let title: String
    @Binding var answer: FormAnswer
    @State private var selectionPanelOpened: Bool = false
    @Binding var showAnswerState: Bool
    var isEnabled: Bool { answer.isEnabled ?? true }

    var dateString: String? {
        guard let input = answer.input, let timeInterval = TimeInterval(input) else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
    }

    var body: some View {
        VStack {
            HStack(spacing: Spacing.padding1) {
                Text(dateString ?? LocalizationConstants.selectDate)
                    .typography(.body1)
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(Spacing.padding2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.buttonBorderRadius)
                        .fill(backgroundColor)

                    RoundedRectangle(cornerRadius: Spacing.buttonBorderRadius)
                        .stroke(
                            showAnswerState
                            ? answer.answerBackgroundStrokeColor
                            : .clear
                        )
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled, !selectionPanelOpened else { return }
                // hide current keybaord if presented,
                // delay needed to wait until keyboard is dismissed
                stopEditing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectionPanelOpened.toggle()
                }
            }
        }
        .sheet(isPresented: $selectionPanelOpened) {
            if #available(iOS 16.4, *) {
                FormDatePickerView(
                    title: title,
                    answer: $answer,
                    selectionPanelOpened: $selectionPanelOpened
                )
                .presentationDetents([.fraction(0.35)])
            } else {
                FormDatePickerView(
                    title: title,
                    answer: $answer,
                    selectionPanelOpened: $selectionPanelOpened
                )
            }
        }
    }
}

extension FormDateDropdownAnswersView {
    // MARK: Colors

    private var backgroundColor: Color {
        if !isEnabled {
            .semantic.medium
        } else {
            .semantic.background
        }
    }

    private var textColor: Color {
        if dateString.isNil || !isEnabled {
            .semantic.muted
        } else {
            .semantic.title
        }
    }
}

struct FormDatePickerView: View {

    let title: String
    @Binding var answer: FormAnswer
    @Binding var selectionPanelOpened: Bool

    private var minDate: Date {
        if let minValue = answer.validation?.metadata?[.minValue], let timeInterval = TimeInterval(minValue) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return .distantPast
    }

    private var maxDate: Date {
        if let maxValue = answer.validation?.metadata?[.maxValue], let timeInterval = TimeInterval(maxValue) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return .distantFuture
    }

    var body: some View {
        NavigationView {
            datePicker
                .padding(.vertical, Spacing.padding1)
                .padding(.horizontal, Spacing.padding2)
                .background(Color.semantic.light)
                .navigationBarItems(
                    trailing: Button(LocalizationConstants.done) {
                        if answer.input.isNilOrEmpty, maxDate != .distantFuture {
                            answer.input = String(maxDate.timeIntervalSince1970)
                        }
                        selectionPanelOpened.toggle()
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var datePicker: some View {
        DatePicker(
            selection: Binding(
                get: {
                    guard let input = answer.input, let timeInterval = TimeInterval(input) else {
                        return Date()
                    }
                    return Date(timeIntervalSince1970: timeInterval)
                },
                set: {
                    answer.input = String($0.timeIntervalSince1970)
                }
            ),
            in: minDate...maxDate,
            displayedComponents: .date,
            label: EmptyView.init
        )
        .datePickerStyle(.wheel)
        .padding(Spacing.padding1)
        .background(Color.semantic.light)
    }
}
