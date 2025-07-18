# Gemini役割制限システム

## 概要

このシステムは、Gemini MCPが最初の要件定義書・外部仕様書の作成のみを行い、それ以降はレビュー専任に徹する仕組みを提供します。

## 設計思想

### 問題意識
- Geminiが詳細仕様書やコードを直接編集することで、Developer本来の役割が侵害される
- 役割分担の曖昧さが開発プロセスに混乱を招く
- 品質管理の責任範囲が不明確になる

### 解決アプローチ
- **Phase単位の権限制御**: 開発段階に応じた厳格な役割制限
- **プロンプト自動生成**: 制限に応じた適切なプロンプトを自動作成
- **事前チェック機能**: 作業実行前の必須確認システム

## 実装内容

### 1. 役割制限スクリプト
```bash
/workspace/autodevg/scripts/validate_gemini_role.sh
```

**機能**:
- Phase（開発段階）と Task（作業種別）の組み合わせによる権限判定
- 結果に応じたプロンプトテンプレートの自動生成
- 制限違反時の警告メッセージ出力
- 全チェック結果のログ記録

### 2. Phase定義

#### Phase 1: requirements
**許可作業**:
- ✅ 要件定義書作成 (create_requirements)
- ✅ 外部仕様書作成 (create_external_spec)
- ✅ レビュー・評価 (review)

**禁止作業**:
- ❌ 詳細仕様書編集
- ❌ コード編集

#### Phase 2: detailed_spec
**許可作業**:
- ✅ レビュー・評価 (review)

**禁止作業**:
- ❌ 詳細仕様書の直接編集
- ❌ テスト手順書の直接編集
- ❌ 文書の書き直し

#### Phase 3: implementation
**許可作業**:
- ✅ コードレビュー (review)
- ✅ テスト評価 (review)

**禁止作業**:
- ❌ ソースコードの直接編集
- ❌ テストファイルの直接編集
- ❌ 実装ファイルの直接作成

### 3. チェック結果の種類

| 結果 | 意味 | 対応 |
|------|------|------|
| ALLOWED | 作業実行許可 | 通常のGemini MCP呼び出し |
| REVIEW_ONLY | レビューのみ許可 | レビュー専用プロンプト使用 |
| FORBIDDEN | 作業禁止 | 警告表示、作業中止 |

### 4. プロンプトテンプレート自動生成

#### 許可時のプロンプト
```
【承認済み作業依頼】
Phase: requirements
作業種別: create_requirements
実行時刻: 2025-07-18 15:30:00 JST

以下の作業を実行してください：
[作業内容を記載]
```

#### レビュー専用プロンプト
```
【レビュー依頼のみ】
Phase: detailed_spec
実行時刻: 2025-07-18 15:30:00 JST

以下の文書をレビューしてください。問題点や改善点を指摘してください。
⚠️ 注意：編集や書き直しは行わず、レビューコメントのみ提供してください。

[レビュー対象文書の内容]
```

#### 禁止時の警告
```
🚨 Gemini役割制限警告
現在のPhase: detailed_spec
制限内容: Geminiによる文書編集は禁止されています
許可作業: レビュー・評価・指摘の提供のみ
対応方法: Developer自身が修正を実施してください
```

## 使用方法

### 1. 基本的な使用
```bash
# Phase 1での要件定義書作成
./scripts/validate_gemini_role.sh requirements create_requirements

# Phase 2での詳細仕様書レビュー
./scripts/validate_gemini_role.sh detailed_spec review

# Phase 3でのコードレビュー
./scripts/validate_gemini_role.sh implementation review
```

### 2. Manager指示書での統合使用
```bash
# 作業前のチェック
./scripts/validate_gemini_role.sh requirements create_requirements

# 許可された場合のみ実行
if [ $? -eq 0 ]; then
    # 生成されたプロンプトテンプレートを使用
    PROMPT_TEMPLATE=$(cat /tmp/autodevg_status/gemini_prompt_template.txt)
    mcp__gemini-cli__geminiChat --prompt "$PROMPT_TEMPLATE"
else
    # 警告内容を表示
    cat /tmp/autodevg_status/gemini_warning.txt
fi
```

### 3. 結果確認
```bash
# チェック結果の確認
echo $?  # 0=許可, 1=制限

# 生成されたファイルの確認
ls /tmp/autodevg_status/
# - gemini_prompt_template.txt (許可時)
# - gemini_warning.txt (制限時)
# - gemini_role_log.txt (全チェック履歴)
```

## ワークフロー統合

### Manager指示書での統合
1. **Phase 1**: 要件定義書・外部仕様書作成時の事前チェック
2. **Phase 2**: 詳細仕様書レビュー時の事前チェック
3. **Phase 3**: コードレビュー時の事前チェック

### 共通の実行パターン
```bash
# 1. 役割制限チェック
./scripts/validate_gemini_role.sh [PHASE] [TASK]

# 2. 結果に応じた分岐
if [ $? -eq 0 ]; then
    # 許可: Gemini MCP実行
    mcp__gemini-cli__geminiChat --prompt "[適切なプロンプト]"
else
    # 制限: 警告表示・作業変更
    cat /tmp/autodevg_status/gemini_warning.txt
fi
```

## 期待される効果

### 1. 役割分担の明確化
- Geminiは初期文書作成とレビューに専念
- Developerは詳細仕様書作成とコーディングに専念
- 責任範囲の明確な分離

### 2. 品質保証の向上
- レビュー専任による客観的な品質チェック
- 編集権限の制限による一貫性の確保
- 段階的な品質向上プロセス

### 3. 開発効率の向上
- 役割混乱の防止による作業効率化
- 適切な権限分離による責任の明確化
- 自動化されたチェック機能による手間削減

## 注意事項

### 1. スクリプトの実行権限
```bash
# 実行権限の確認・付与
chmod +x /workspace/autodevg/scripts/validate_gemini_role.sh
```

### 2. 共有ディレクトリの確保
```bash
# 共有ディレクトリの作成
mkdir -p /tmp/autodevg_status
```

### 3. エラーハンドリング
- チェック結果の必須確認
- 制限時の適切な代替手段の実行
- ログ記録の継続実施

## 今後の拡張可能性

### 1. より詳細なタスク分類
- 文書種別による細かい権限制御
- 編集レベルによる段階的制限

### 2. 動的な権限管理
- プロジェクト進捗に応じた動的な権限変更
- 成果物品質による権限拡張

### 3. 監査・レポート機能
- 権限使用状況の詳細レポート
- 制限違反の統計分析

## 結論

このGemini役割制限システムにより、初期の要件定義・外部仕様書作成後は、Geminiが詳細仕様書やコードを直接編集することを完全に防ぎ、レビュー専任に徹する体制を技術的に保証します。これによって、各役割の責任範囲が明確化され、より効率的で品質の高い開発プロセスが実現されます。