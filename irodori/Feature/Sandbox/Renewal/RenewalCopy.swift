//
//  RenewalCopy.swift
//  irodori - Sandbox
//
//  相棒のセリフ (口調5種)。本番では Gemini 3.8 Flash が JSON で返す想定の文言を、
//  Sandbox ではテンプレートで再現する。
//
//  文章の黄金律 (partner_communication_and_growth_ux_design.md §2 / 最新 03 の 45〜65字):
//   - 1回 45〜65字・最大2文 / 根拠は最大2つ / 上から目線の評価をしない / 絵文字0〜1、「！」連発禁止
//   - 固有名詞 (手持ち服の名前) か前回の行動を必ず1つ織り込む
//

import Foundation

enum RenewalCopy {

    /// 黄金律の文字数レンジ (最新ドキュメント 03 を優先)
    static let idealRange = 45...65

    // MARK: - ① 朝のホーム (home_greeting)

    struct GreetingContext {
        let weather: RenewalWeather
        let hero: String?
        let last: String?
        let value: String          // Q2 の大事にしている価値
        let weekdayFamily: String  // 平日に多かった配色 (E 用)
        let scopeLabel: String     // 今日 / 明日 / 週末
    }

    static func greeting(angle: RenewalDailyAngle, tone: RenewalTone, ctx c: GreetingContext) -> String {
        let t = c.weather.tempMax
        let cond = c.weather.condition
        let h = c.hero ?? "定番の服"
        let last = c.last ?? "きれいめ"
        let v = c.value
        let abs = Swift.abs(c.weather.diffFromYesterday)
        let down = c.weather.diffFromYesterday < 0
        let dir = down ? "下がって" : "上がって"
        let care = down || c.weather.needsOuter ? "暖かく羽織れる" : "軽やかに動ける"
        let fam = c.weekdayFamily
        let day = c.scopeLabel

        switch (angle, tone) {
        // Stage 1 (手持ち0着)
        case (.birth, .gentle): return "\(day)は\(t)℃で\(cond)だね。あなたが大事にしている『\(v)』を軸に、さらっと着られる3案を選んだよ。"
        case (.birth, .casual): return "\(day)は\(t)℃で\(cond)！あなたが大事にしてる『\(v)』を軸に、さらっと着られる3案を選んでみたよ。"
        case (.birth, .cool): return "\(day)は最高\(t)℃、\(cond)。回答いただいた『\(v)』を軸に、無理なく着られる3案を選定しました。"
        case (.birth, .spicy): return "\(day)は\(t)℃で\(cond)よ。あなたが大事な『\(v)』は外さずに、ちゃんと着られる3案にしておいたわ。"
        case (.birth, .kansai): return "\(day)は\(t)℃で\(cond)やで。あんたが大事にしてる『\(v)』を軸に、さらっと着れる3案選んどいたよ。"

        // A. 新着アイテム主役日
        case (.newItem, .gentle): return "\(t)℃の\(cond)だね。登録してくれた『\(h)』を主役に、手持ちで組めるコーデを作ってみたよ。"
        case (.newItem, .casual): return "\(t)℃で\(cond)！こないだ登録してくれた『\(h)』、めっちゃ使えるから主役にして組んでみたよ。"
        case (.newItem, .cool): return "最高\(t)℃、\(cond)。新しく登録された『\(h)』を軸に、手持ちで組める3案を選定しました。"
        case (.newItem, .spicy): return "\(t)℃の\(cond)よ。せっかく登録した『\(h)』、しまい込まないで\(day)の主役にしなさい。"
        case (.newItem, .kansai): return "\(t)℃で\(cond)やね。登録してくれた『\(h)』、めっちゃええ感じやから主役にして組んどいたで。"

        // B. カレンダー着回し日
        case (.rotation, .gentle): return "昨日は\(last)だったから、\(day)は\(h)で少し気分を変えた3案にしてみたよ。\(t)℃の\(cond)だね。"
        case (.rotation, .casual): return "昨日は\(last)だったし、\(day)は\(h)で気分を変えてみよ。\(t)℃の\(cond)にちょうどいい3案だよ。"
        case (.rotation, .cool): return "昨日は\(last)でした。\(day)は\(h)で印象を変え、\(t)℃の\(cond)に合う3案を選定しています。"
        case (.rotation, .spicy): return "昨日は\(last)だったでしょ。同じ服ばっかりにならないよう、\(day)は\(h)で組んでおいたわ。"
        case (.rotation, .kansai): return "昨日は\(last)やったし、\(day)は\(h)で気分変えてこ。\(t)℃の\(cond)にちょうどええ3案やで。"

        // C. 眠っている服の救出日
        case (.rescue, .gentle): return "手持ちの『\(h)』、\(t)℃の\(day)にちょうどいいよ。しばらく出番がなかったから主役にしてみたよ。"
        case (.rescue, .casual): return "『\(h)』最近出番なかったよね。\(t)℃の\(day)にぴったりだから、主役にして組んでみたよ。"
        case (.rescue, .cool): return "『\(h)』は直近2週間の着用がありません。\(t)℃の\(day)に適しているため、主役に据えました。"
        case (.rescue, .spicy): return "『\(h)』、ずっと眠らせてるじゃない。\(t)℃の\(day)にちょうどいいから、主役で着なさい。"
        case (.rescue, .kansai): return "『\(h)』、最近出番なかったやろ。\(t)℃の\(day)にぴったりやから、主役にしといたで。"

        // D. 天気・寒暖差ケア日
        case (.weather, .gentle):
            return c.weather.isRain
                ? "\(day)は雨で\(t)℃だよ。濡れても気にならない\(h)を軸に、『\(v)』も大事にした3案にしたよ。"
                : "昨日より\(abs)℃\(dir)\(t)℃になるよ。『\(v)』は保ちつつ、\(care)3案にしておいたよ。"
        case (.weather, .casual):
            return c.weather.isRain
                ? "\(day)は雨で\(t)℃だって。濡れても平気な\(h)を軸にして、『\(v)』もちゃんと考えた3案だよ。"
                : "昨日より\(abs)℃\(dir)\(t)℃だって。『\(v)』はそのままで、\(care)3案にしといたよ。"
        case (.weather, .cool):
            return c.weather.isRain
                ? "\(day)は雨、最高\(t)℃です。濡れても扱いやすい\(h)を軸に、『\(v)』を維持した3案です。"
                : "前日比\(down ? "−" : "+")\(abs)℃の\(t)℃です。『\(v)』を維持しつつ、\(care)3案を選定しました。"
        case (.weather, .spicy):
            return c.weather.isRain
                ? "\(day)は雨で\(t)℃よ。濡れて後悔しないよう\(h)を軸にしたわ。『\(v)』もちゃんと守ってあげる。"
                : "昨日より\(abs)℃\(dir)\(t)℃よ。『\(v)』は守りつつ、\(care)3案にしてあげたわ。油断しないこと。"
        case (.weather, .kansai):
            return c.weather.isRain
                ? "\(day)は雨で\(t)℃やで。濡れても気にならん\(h)を軸に、『\(v)』も大事にした3案にしといたで。"
                : "昨日より\(abs)℃\(dir)\(t)℃やで。『\(v)』はそのままに、\(care)3案にしといたよ。"

        // E. 週末の気分転換日
        case (.weekend, .gentle): return "週末だね。平日は\(fam)が多かったから、手持ちの\(h)で少し気分を変えたお出かけ案も入れたよ。"
        case (.weekend, .casual): return "週末だね！平日は\(fam)多めだったから、\(h)でちょっと遊んだお出かけ案も入れてみたよ。"
        case (.weekend, .cool): return "週末です。平日は\(fam)が中心だったため、\(h)で変化をつけたお出かけ案を含めています。"
        case (.weekend, .spicy): return "週末くらい平日の\(fam)から離れなさい。手持ちの\(h)で、少し攻めた案も入れておいたわよ。"
        case (.weekend, .kansai): return "週末やね。平日は\(fam)多めやったし、\(h)でちょっと遊んだお出かけ案も入れといたで。"
        }
    }

    // MARK: - 手持ち0〜2着のときだけ吹き出しに添える1行 (data_nudge_one_liner)

    static func nudge(tone: RenewalTone) -> String {
        switch tone {
        case .gentle: return "写真フォルダから、いつもの服を見つけてみない？"
        case .casual: return "写真フォルダからいつもの服、探してみよっか？"
        case .cool: return "写真フォルダから手持ち服を自動で検出できます"
        case .spicy: return "写真フォルダの服、ちょっと見せなさいよ"
        case .kansai: return "写真フォルダからいつもの服、探してみいひん？"
        }
    }

    // MARK: - 推薦カードの理由 (card_reasons)

    static func cardReason(recipe r: RenewalRecipe, tone: RenewalTone, weather w: RenewalWeather) -> String {
        let a = r.ownedItems.first?.name ?? r.missingItems.first?.name ?? "定番の服"
        let b = r.ownedItems.dropFirst().first?.name ?? r.missingItems.dropFirst().first?.name ?? "定番の服"
        let m = r.missingItems.first?.name ?? "羽織り"
        let t = w.tempMax
        switch (r.kind, tone) {
        case (.owned, .gentle): return "手持ちの\(a)×\(b)だけで完成。写真みたいに袖をひと折りすると、\(t)℃の日に軽やかに見えるよ。"
        case (.owned, .casual): return "手持ちの\(a)×\(b)だけで完成！袖をひと折りすると、写真っぽく軽やかになるよ。"
        case (.owned, .cool): return "手持ちの\(a)×\(b)のみで成立します。袖を一折りすると、写真に近い軽さが出ます。"
        case (.owned, .spicy): return "手持ちの\(a)×\(b)だけで十分よ。袖はひと折りしなさい、それだけで垢抜けるわ。"
        case (.owned, .kansai): return "手持ちの\(a)×\(b)だけで完成やで。袖ひと折りしたら、写真みたいに軽う見えるよ。"

        case (.partial, .gentle): return "手持ちの\(a)に、\(m)を1点足すとこんな柔らかい雰囲気も作れるよ。\(t)℃でも快適だよ。"
        case (.partial, .casual): return "手持ちの\(a)に\(m)を1点足すと、こんな雰囲気にもできちゃう。\(t)℃でもちょうどいいよ。"
        case (.partial, .cool): return "手持ちの\(a)に\(m)を1点追加すると、この雰囲気を再現できます。\(t)℃に適した構成です。"
        case (.partial, .spicy): return "手持ちの\(a)に\(m)を1点足すだけ。それでこの雰囲気になるのよ、覚えておきなさい。"
        case (.partial, .kansai): return "手持ちの\(a)に\(m)を1点足したら、こんな雰囲気もいけるで。\(t)℃でもちょうどええよ。"

        case (.zero, .gentle): return "定番の\(a)×\(b)で組んだ案だよ。似た服を持っていたら『持ってる』で教えてね。"
        case (.zero, .casual): return "定番の\(a)×\(b)で組んでみた。似たの持ってたら『持ってる』で教えてくれたら嬉しい。"
        case (.zero, .cool): return "定番の\(a)×\(b)による構成です。類似品をお持ちなら『持ってる』で登録できます。"
        case (.zero, .spicy): return "定番の\(a)×\(b)で組んだわ。似たの持ってるなら『持ってる』で教えなさい。"
        case (.zero, .kansai): return "定番の\(a)×\(b)で組んだで。似たの持ってたら『持ってる』で教えてな。"

        case (.discovery, .gentle): return "いつもと少し違う\(m)合わせ。手持ちの\(a)となら、無理なく挑戦できる組み合わせだよ。"
        case (.discovery, .casual): return "ちょっと新鮮な\(m)合わせ。手持ちの\(a)となら意外とハマるから、見てみて。"
        case (.discovery, .cool): return "普段と異なる\(m)の組み合わせです。手持ちの\(a)があれば試しやすい構成です。"
        case (.discovery, .spicy): return "たまには\(m)合わせも着てみなさい。手持ちの\(a)となら失敗しないわ。"
        case (.discovery, .kansai): return "ちょっと新鮮な\(m)合わせやで。手持ちの\(a)となら、案外ええ感じやよ。"
        }
    }

    // MARK: - ③ 「今日着る」決定時 (見送りのひとこと)

    static func sendoff(recipe r: RenewalRecipe, tone: RenewalTone, scope: RenewalScope) -> String {
        let pair = r.pairText
        let d = scope.label
        if scope != .today {
            switch tone {
            case .gentle: return "\(d)は\(pair)で決まりだね。カレンダーに入れておいたから、当日は着るだけだよ。"
            case .casual: return "\(d)は\(pair)で決まり！カレンダーに入れといたから、当日は着るだけだよ。"
            case .cool: return "\(d)は\(pair)で確定しました。カレンダーに登録済みのため、当日の判断は不要です。"
            case .spicy: return "\(d)は\(pair)ね。カレンダーに入れといたから、当日は迷わないこと。"
            case .kansai: return "\(d)は\(pair)で決まりやね。カレンダーに入れといたで、当日は着るだけや。"
            }
        }
        if r.isDiscovery {
            switch tone {
            case .gentle: return "今日は少し新鮮な組み合わせを選んだね。こういう挑戦も似合うと思ってたよ、いい1日を。"
            case .casual: return "今日はちょっと新鮮なやつ選んだね。そういうのも似合うと思ってた、いい1日を！"
            case .cool: return "普段と異なる選択ですね。十分に似合う範囲の組み合わせです。良い1日を。"
            case .spicy: return "あら、今日は攻めたわね。そういうの似合うって思ってたのよ。いってらっしゃい。"
            case .kansai: return "今日はちょっと新鮮なの選んだなぁ。そういうのも似合うと思ってたで、いってらっしゃい。"
            }
        }
        switch tone {
        case .gentle: return "\(pair)、間違いなく似合う組み合わせだね。気をつけていってらっしゃい。"
        case .casual: return "\(pair)、絶対似合うやつ！気をつけていってらっしゃい、いい1日を。"
        case .cool: return "\(pair)は安定した組み合わせです。カレンダーに記録しました。いってらっしゃい。"
        case .spicy: return "\(pair)、似合うに決まってるでしょ。胸張っていってらっしゃい。"
        case .kansai: return "\(pair)、めっちゃ似合う組み合わせやん。気ぃつけていってらっしゃい。"
        }
    }

    // MARK: - ② 登録直後の「発見フィードバック」

    enum RegisterKind {
        case first(name: String)
        case theme(families: String)
        case accent(name: String, base: String)
        case batch(count: Int, families: String)
    }

    static func registerFeedback(_ kind: RegisterKind, tone: RenewalTone) -> String {
        switch (kind, tone) {
        case (.first(let n), .gentle): return "\(n)、覚えやすい定番から教えてくれてありがとう。まずはこれを軸に明日のコーデを組むね。"
        case (.first(let n), .casual): return "\(n)から教えてくれてありがと！まずはこれを軸に、明日のコーデ組んでみるね。"
        case (.first(let n), .cool): return "\(n)を登録しました。まずはこれを軸に、明日の提案を組み立てます。"
        case (.first(let n), .spicy): return "\(n)ね、いい定番から来たじゃない。まずはこれを軸に明日のコーデを組んであげる。"
        case (.first(let n), .kansai): return "\(n)から教えてくれておおきに。まずはこれ軸に、明日のコーデ組んでみるで。"

        case (.theme(let f), .gentle): return "\(f)が揃ってきたね。あなたの好きな配色、すごく伝わってきたよ。明日から早速使うね。"
        case (.theme(let f), .casual): return "\(f)が揃ってきたね！好きな配色、だんだん分かってきたよ。明日から使うね。"
        case (.theme(let f), .cool): return "\(f)の比率が高まっています。好みの配色として、明日の提案に反映します。"
        case (.theme(let f), .spicy): return "\(f)ばっかり集まってきたわね。好きなのは伝わったわ、明日から使い倒すわよ。"
        case (.theme(let f), .kansai): return "\(f)が揃ってきたなぁ。好きな配色、ちゃんと伝わってきたで。明日から使うね。"

        case (.accent(let n, let b), .gentle): return "いつものベーシックカラーに、きれいな\(n)が加わったね。手持ちの\(b)と合わせるのが楽しみ。"
        case (.accent(let n, let b), .casual): return "ベーシックな服に\(n)が加わった！手持ちの\(b)と合わせるの、今から楽しみ。"
        case (.accent(let n, let b), .cool): return "\(n)が加わり、配色の幅が広がりました。手持ちの\(b)との組み合わせを提案します。"
        case (.accent(let n, let b), .spicy): return "あら、\(n)なんて持ってたのね。手持ちの\(b)と合わせたら絶対いいわよ。"
        case (.accent(let n, let b), .kansai): return "いつもの服に\(n)が加わったやん。手持ちの\(b)と合わせるの楽しみやわ。"

        case (.batch(let c, let f), .gentle): return "写真から\(c)着見つけたよ。\(f)が多めなんだね、明日の提案から早速使うね。"
        case (.batch(let c, let f), .casual): return "写真から\(c)着見つけたよ！\(f)多めなんだね、明日の提案から早速使うね。"
        case (.batch(let c, let f), .cool): return "写真から\(c)着を検出しました。\(f)が中心です。明日の提案から反映します。"
        case (.batch(let c, let f), .spicy): return "写真から\(c)着見つけたわ。\(f)ばっかりね、明日からちゃんと活かしてあげる。"
        case (.batch(let c, let f), .kansai): return "写真から\(c)着見つけたで。\(f)多めなんやね、明日の提案から早速使うわ。"
        }
    }

    // MARK: - 見送り・👎 への返事

    static func dislikeAck(_ reason: RenewalDislikeReason, tone: RenewalTone) -> String {
        let r = reason.label
        switch tone {
        case .gentle: return "教えてくれてありがとう。『\(r)』は覚えておくね、次はそこを外して組むよ。"
        case .casual: return "了解！『\(r)』だったんだね。次はそこを外して組み直してみるよ。"
        case .cool: return "『\(r)』を記録しました。次回の提案から該当する要素を外します。"
        case .spicy: return "『\(r)』ね、わかったわ。次はちゃんと外してあげるから安心しなさい。"
        case .kansai: return "『\(r)』やね、覚えとくわ。次はそこ外して組むから任しといて。"
        }
    }

    // MARK: - 口調変更の直後

    static func toneChanged(_ tone: RenewalTone) -> String {
        switch tone {
        case .gentle: return "これからは、やさしく丁寧にお話しするね。いつでも気軽に変えてね。"
        case .casual: return "了解！これからはもっと気軽に話すね。あらためてよろしく。"
        case .cool: return "了解しました。これからは簡潔にお伝えします。"
        case .spicy: return "わかったわ。これからは遠慮なく言わせてもらうわよ。"
        case .kansai: return "ほな、これからは関西弁でいくで。よろしゅうな。"
        }
    }

    /// 口調選択シートのプレビュー例文 (同じ内容でも口調でこう変わる)
    static func tonePreview(_ tone: RenewalTone) -> String {
        switch tone {
        case .gentle: return "20℃で気持ちいい晴れだね。登録してくれた白シャツを主役に、落ち着く3案を組んでみたよ。"
        case .casual: return "今日は20℃でいい天気！こないだ登録してくれた白シャツ、今日めっちゃ使えるから3パターン組んでみたよ。"
        case .cool: return "最高20℃の晴れ。手持ちの白シャツと黒スラックスを軸に、最もバランスの良い3案を選定しました。"
        case .spicy: return "今日は20℃よ。昨日と同じような服ばっかり着ないの。手持ちの白シャツでスッキリ見せる3案にしておいたわ。"
        case .kansai: return "今日は20℃で過ごしやすいで。登録してくれた白シャツ、めっちゃええ感じやからこれ軸に3つ組んどいたよ。"
        }
    }

    // MARK: - 相棒誕生 (Step 2) の最初の挨拶

    static func birthGreeting(_ a: RenewalAnswers) -> String {
        let imp = a.impression.shortWord
        let v = a.priority.valueWord
        switch a.tone {
        case .gentle: return "はじめまして。『\(imp)』に見られたくて、\(v)も大事にしたいあなたへ。毎朝3案を届けるね。"
        case .casual: return "はじめまして！『\(imp)』に見られたいあなたに、\(v)重視で毎朝3案届けるね。"
        case .cool: return "はじめまして。『\(imp)』と『\(v)』を基準に、毎朝3案を理由つきで提案します。"
        case .spicy: return "はじめまして。『\(imp)』に見せたいなら任せなさい。\(v)も外さず毎朝3案出すわ。"
        case .kansai: return "はじめまして。『\(imp)』に見られたいんやね。\(v)も大事に、毎朝3案届けるで。"
        }
    }

    // MARK: - 2択比較の完了

    static func tasteVoteDone(_ family: RenewalColorFamily, tone: RenewalTone) -> String {
        let f = family.label
        switch tone {
        case .gentle: return "教えてくれてありがとう。\(f)の雰囲気に惹かれるんだね、次の提案に少しずつ混ぜていくよ。"
        case .casual: return "ありがと！\(f)の雰囲気が好きなんだね。次の提案にちょっとずつ混ぜてみるね。"
        case .cool: return "\(f)の傾向を記録しました。次回以降の提案に段階的に反映します。"
        case .spicy: return "ふうん、\(f)が好きなのね。わかったわ、次からちゃんと混ぜてあげる。"
        case .kansai: return "\(f)の雰囲気が好きなんやね。次の提案にちょっとずつ混ぜていくで。"
        }
    }
}
