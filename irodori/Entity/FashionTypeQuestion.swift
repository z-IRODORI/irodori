//
//  FashionTypeQuestion.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import Foundation

struct FashionTypeQuestion: Identifiable {
    let id: Int
    let text: String
    let exampleText: String
}

extension FashionTypeQuestion {
    static let questions: [FashionTypeQuestion] = [
        FashionTypeQuestion(
            id: 1,
            text: "SNSや雑誌、街のディスプレイで「今年の流行」をチェックするのが楽しい。",
            exampleText: "季節の変わり目に「今年はどんな色が流行るんだろう？」とワクワクして調べ始めるタイプですか？"
        ),
        FashionTypeQuestion(
            id: 2,
            text: "自分のスタイルは既に決まっており、流行に関係なく「いつもの感じ」が一番落ち着く。",
            exampleText: "10年前の自分が着ていた服を、今そのまま着ても違和感がない、あるいは「自分の制服」のような定番が決まっている方は高い数値になります。"
        ),
        FashionTypeQuestion(
            id: 3,
            text: "服を選ぶとき、周囲の目よりも「自分が今日、どんな気分でいたいか」を優先する。",
            exampleText: "雨の日でも自分が大好きな明るい色の服を着ることで、自分のテンションを上げたい！と思うタイプですか？"
        ),
        FashionTypeQuestion(
            id: 4,
            text: "「なりたい自分」や「理想のイメージ」に近づくためのツールとして服を選んでいる。",
            exampleText: "「今日は仕事ができる人に見せたい」「大人っぽく見られたい」など、自分のなりたい姿を服で作ろうとしますか？"
        ),
        FashionTypeQuestion(
            id: 5,
            text: "誰かと会うときは、その相手が「自分にどんな印象を抱くか」をまず最初に考える。",
            exampleText: "初対面の人に会うとき「この服なら失礼がないか」「清潔感があって安心してもらえるか」を真っ先に考えますか？"
        ),
        FashionTypeQuestion(
            id: 6,
            text: "出かける場所（TPO）のルールや空気に、違和感なく溶け込んでいることが心地よい。",
            exampleText: "高級レストランや親戚の集まりで「浮いていないこと」を確認して、初めて安心してその場を楽しめるタイプですか？"
        ),
        FashionTypeQuestion(
            id: 7,
            text: "多少歩きにくかったり、肩が凝ったりしても、シルエットが綺麗な服を選びたい。",
            exampleText: "「このヒールを履くと足が綺麗に見えるから、多少の痛みは我慢！」と、鏡の中の自分を優先することがありますか？"
        ),
        FashionTypeQuestion(
            id: 8,
            text: "結局、一日中ストレスなく動ける「着心地の良さ」が、自分にとっての正解だ。",
            exampleText: "デザインがいくら良くても、素材がチクチクしたり、動きにくかったりする服は、結局クローゼットの肥やしになってしまいますか？"
        ),
        FashionTypeQuestion(
            id: 9,
            text: "服を買うときは、まず値札を見て「この価格なら納得できるか（コスパ）」を吟味する。",
            exampleText: "同じようなデザインなら「1円でも安い方」や「セールでどれだけお得か」を重視して選びますか？"
        ),
        FashionTypeQuestion(
            id: 10,
            text: "高価であっても、素材の背景やブランドの哲学に共感すれば、長く着るつもりで投資する。",
            exampleText: "「一生モノ」という言葉に弱かったり、数年後にクタクタにならず、むしろ味が出るような良い素材のものを一着持っていたいと思いますか？"
        )
    ]
}
