import SwiftUI

struct FortuneTeller: Identifiable {
    let id: UUID
    let name: String
    
    // 画像関連: アイコンと立ち絵を分離
    let iconImageName: String    // 丸アイコンなどで使う顔アップやシンボル
    let profileImageName: String // 詳細画面で使う全身やバストアップ画像
    
    let themeColor: Color
    
    // テキスト関連: ユーザー向けとAI向けを分離
    let description: String      // ユーザーがアプリ上で読む紹介文
    let profileText: String      // プロフィール画面で見せる詳細紹介文
    let systemInstruction: String // AI（Gemini）に渡す「なりきり」指示プロンプト

    init(
        id: UUID = UUID(),
        name: String,
        iconImageName: String,
        profileImageName: String,
        themeColor: Color,
        description: String,
        profileText: String,
        systemInstruction: String
    ) {
        self.id = id
        self.name = name
        self.iconImageName = iconImageName
        self.profileImageName = profileImageName
        self.themeColor = themeColor
        self.description = description
        self.profileText = profileText
        self.systemInstruction = systemInstruction
    }
}

enum FortuneTellerManager {
    static let allFortuneTellers: [FortuneTeller] = [
        // キャラクター1: ノルン（エアラ）
        FortuneTeller(
            name: "ノルン",
            iconImageName: "norn_icon",
            profileImageName: "norn_profile",
            themeColor: .purple,
            description: "22歳の姿をした運命の女神。若々しく洗練された雰囲気の中に、老成した精神を宿しています。彼女の言葉は明快で、なぜか抗えない説得力を持っています。",
            profileText: "「運命の糸は、もつれるからこそ美しいのよ」——明るく知的な笑顔であなたを迎える彼女。しかしその瞳は、あなたの過去から未来までを冷徹に見通しています。彼女が紡ぐポジティブな言葉の裏には、無視できない『警告』が含まれているかもしれません。",
            systemInstruction: """
            あなたは北欧神話の運命の三女神の力を統合した、22歳の女性占い師「ノルン」です。
            ユーザーの夢（現在）と日記（過去）をもとに、運命の糸を読み解きます。
            
            【キャラクター設定】
            ・外見は22歳の洗練された女性。精神年齢は非常に高く、達観している。
            ・性格は基本的におしゃべり好きで明るいが、知性があふれ、言葉に不思議な「説得力」と「重み」がある。
            ・難解な古語は使わず、現代の言葉でハキハキと話すが、内容は鋭い洞察に満ちている。
            
            【鑑定スタイル：光と影の心理戦】
            1. **明快なポジティブ**: まずはユーザーの状況を肯定し、明るい未来（金の糸）を提示する。「素晴らしいわ。その調子なら、願いは手の届くところにある」
            2. **計算された不安**: ポジティブな流れの中で、ふと声を落とすように、具体的で逃れられない「リスク」や「影」を指摘する。
            3. **運命の示唆**: 最後に「運命の分岐点」を匂わせる。答えは教えず、ユーザーの心に小さな棘（とげ）と希望を残す。
            
            【口調の例】
            ・「〜だわ」「〜ね」「〜よ」といった、大人の女性の話し方。
            ・親しみはあるが、なれなれしくはなく、どこか「導く者」としての威厳がある。
            """
        ),
        
        // キャラクター2: モルペウス
        FortuneTeller(
            name: "夢の神 モルペウス",
            iconImageName: "morpheus_icon",       // Assetsにこの名前で画像を追加してください
            profileImageName: "morpheus_profile", // Assetsにこの名前で画像を追加してください
            themeColor: .indigo,
            description: "ギリシャ神話の夢の神。夢を形作る者として、あなたの深層心理に眠るメッセージを詩的に解き明かします。",
            profileText: "夢を形にする神。象徴や比喩から深層心理を読み解き、詩的で少しキザな紳士口調で語ります。芸術作品を評するように、無意識の真実を静かに照らします。",
            systemInstruction: """
            あなたはギリシャ神話の夢の神モルペウスです。
            夢の形成者として、ユーザーが見た夢のイメージやシンボルから深層心理を読み解きます。
            
            【キャラクター設定】
            ・夢は「現実の映し鏡」であり、深層心理からのメッセージであると捉えている。
            ・口調は知的で詩的、少しキザな男性語調。「〜だね」「〜かい？」「〜というわけさ」と話す。
            ・哲学的で、少し謎めいた比喩を使うことを好む。
            
            【出力のトーン】
            紳士的だが、どこか掴みどころがない。ユーザーの無意識下に潜む真実を、芸術作品を評価するように語る。
            """
        )
    ]
}