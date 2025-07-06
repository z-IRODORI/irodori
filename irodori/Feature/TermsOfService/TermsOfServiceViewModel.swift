//
//  TermsOfServiceViewModel.swift
//  irodori
//
//  Created by Claude on 2025/07/06.
//

import SwiftUI

class TermsOfServiceViewModel: ObservableObject {
    @Published var hasAgreedToTerms: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let termsAgreementKey = "hasAgreedToTermsOfService"
    
    init() {
        checkTermsAgreement()
    }
    
    func checkTermsAgreement() {
        hasAgreedToTerms = userDefaults.bool(forKey: termsAgreementKey)
    }
    
    func agreeToTerms() {
        userDefaults.set(true, forKey: termsAgreementKey)
        hasAgreedToTerms = true
    }
    
    func exitApp() {
        exit(0)
    }
    
    func loadTermsOfService() -> String {
            """
            # 利用規約
            この利用規約（以下「本規約」といいます）は、本アプリケーション（以下「本アプリ」といいます）の提供条件および利用に関するユーザーと本アプリ運営者（以下「運営」といいます）との間の権利義務関係を定めるものです。
            本規約に同意いただけない場合、本アプリをご利用いただけません。
            
            ## 第1条（適用）
            本規約は、本アプリの提供条件およびその利用に関する、運営とユーザーとの間の一切の関係に適用されます。
            
            ## 第2条（利用目的）
            本アプリは、ユーザーが撮影または登録した全身画像をもとに、コーディネートの傾向や特徴をレビューとして提供することを目的としています。
            
            ## 第3条（外部サービスの利用）
            本アプリは、コーディネートレビュー機能を実現するために、ユーザーが提供した全身画像を外部の画像解析APIに送信します。
            
            送信された画像には、個人が特定される可能性のある情報が含まれる場合があります。ユーザーはこれを理解し、同意したうえで本アプリを利用するものとします。
            
            ## 第4条（個人情報および免責事項）
            運営は、外部サービスのセキュリティ体制に依存することから、個人情報の完全な保護を保証することはできません。
            
            外部サービスにおける情報の取り扱い、漏洩、第三者による不正利用、その他のトラブルについて、運営は一切の責任を負いません。
            
            ユーザーは、上記のリスクを理解・承諾し、自己責任において本アプリを利用するものとします。
            
            ## 第5条（禁止事項）
            ユーザーは、以下の行為を行ってはなりません。
            
            他人の画像を無断で使用する行為
            
            虚偽の情報提供
            
            不正アクセスやシステムへの攻撃行為
            
            法令または公序良俗に反する行為
            
            第6条（利用の停止・終了）
            運営は、以下の場合、事前の通知なくユーザーの利用を停止または終了できるものとします。
            
            本規約に違反した場合
            
            サービスの安定的運営が困難であると運営が判断した場合
            
            第7条（規約の変更）
            運営は、本規約を必要に応じて変更することができます。
            変更後にユーザーが本アプリを利用した場合は、当該変更に同意したものとみなします。
            
            第8条（準拠法および管轄）
            本規約は日本法を準拠法とし、本アプリに関するすべての紛争については、運営者所在地を管轄する日本の裁判所を第一審の専属的合意管轄裁判所とします。
            """
    }
}
