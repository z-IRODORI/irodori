//
//  OneTimeCodeField.swift
//  irodori
//
//  SMS の認証コードを受け取る入力欄 (UITextField)。
//  SwiftUI の TextField に .oneTimeCode を付けただけでは、キーボード上の「メッセージから」の候補を押しても
//  入らないことがあるため、UIKit の入力欄で受け取る (入力は数字だけ・桁数まで)。
//  見た目は呼び出し側が重ねるマスで出すので、文字とカーソルは透明にする。
//

import SwiftUI
import UIKit

struct OneTimeCodeField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var length: Int = 6

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        // 画面に出た直後はまだウィンドウに載っていないので、少し待ってからキーボードを出す
        if isFocused, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OneTimeCodeField

        init(_ parent: OneTimeCodeField) { self.parent = parent }

        /// 「メッセージから」の自動入力も手入力も、入った後の文字列から数字だけを桁数まで取り出す
        @objc func editingChanged(_ field: UITextField) {
            let digits = String((field.text ?? "").filter(\.isNumber).prefix(parent.length))
            if field.text != digits { field.text = digits }
            if parent.text != digits { parent.text = digits }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }
    }
}
