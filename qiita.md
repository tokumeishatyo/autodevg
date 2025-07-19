# Claude × Gemini で実現する AI協調開発システム「autodevg」

## はじめに

AIを活用した開発支援ツールが注目される中、複数のAIモデルを協調させることで、より高品質な開発を実現する試みを行いました。本記事では、ClaudeとGeminiを組み合わせた開発支援システム「autodevg」について紹介します。

## 背景

従来のAI支援開発では、単一のAIモデルに依存することが多く、以下のような課題がありました：

- 単一視点による思考の偏り
- 客観的なレビューの不足
- 役割分担の曖昧さ

これらの課題を解決するため、異なるAIモデルを明確な役割分担で協調させるシステムを開発しました。

## システム概要

autodevgは、tmuxを活用した4ペイン構成の開発支援システムです。

```
Manager (左上)          Progress Monitor (右上)
    ↓                         ↓
Developer (左下)        Usage Monitor (右下)
```

### 主な特徴

1. **2×2のシンプルな画面構成**
   - 左側：開発作業用（Manager/Developer）
   - 右側：監視用（進捗/使用量）

2. **明確な役割分担**
   - Manager：戦略的判断と実行管理（Claude使用）
   - Developer：実装とテスト（Claude使用）
   - Reviewer：要件定義とレビュー（Gemini MCP経由）

3. **段階的な開発フロー**
   - Phase 1：要件定義・外部仕様（Gemini主導）
   - Phase 2：詳細設計・テスト仕様（Claude主導）
   - Phase 3：実装・レビュー（協調作業）

## 技術的な特徴

### 1. Gemini役割制限システム

Geminiの作業範囲を技術的に制限し、品質を保証します。

```bash:scripts/validate_gemini_role.sh
# Phase判定による権限制御
./scripts/validate_gemini_role.sh requirements create_requirements  # ✅ 許可
./scripts/validate_gemini_role.sh detailed_spec edit_spec         # ❌ 禁止
```

Phase 2以降は、Geminiはレビューのみに専念し、編集作業は行いません。

### 2. 使用量管理システム

Claude APIの使用量を事前チェックし、制限到達前に安全に停止します。

```bash
# 作業開始前の必須チェック
if ! ./scripts/check_usage_before_work.sh Manager "要件定義作成"; then
    echo "使用量制限のため待機します"
    exit 1
fi
```

### 3. 進捗監視システム

作業内容を自動判別し、リアルタイムで進捗を表示します。

```
💭 思考中... (3分経過) ●○○
📝 文書作成中... (7分経過) ●●○
💻 コード作成中... (12分経過) ●●●
```

## 使用方法

### セットアップ

```bash
# リポジトリのクローン
git clone https://github.com/tokumeishatyo/autodevg.git
cd autodevg

# システムの起動
./setup_autodevg_workspace.sh
```

### 開発の開始

```bash
# 1. planning.txtにプロジェクト概要を記載
vi WorkFlow/planning.txt

# 2. Managerペインで/goコマンドを実行
/go
```

### 基本的なワークフロー

1. **要件定義（Gemini）**
   ```bash
   mcp__gemini-cli__geminiChat --prompt "planning.txtに基づいて要件定義書を作成"
   ```

2. **詳細設計（Claude）**
   - Developerが詳細仕様書とテスト仕様書を作成
   - Geminiがレビューのみ実施

3. **実装・レビュー（協調）**
   - Claudeが実装、Geminiがレビュー
   - 段階的な品質向上

## 実装例

### プロジェクト企画書（planning.txt）の例

```markdown:WorkFlow/planning.txt
# プロジェクト概要
Webベースのタスク管理アプリケーションを開発したい

## 要求機能
- ユーザー登録・ログイン機能
- タスクの作成・編集・削除
- 進捗管理（未着手・進行中・完了）

## 技術要件
- フロントエンド：React
- バックエンド：Node.js
```

### 生成される成果物

```
docs/
├── requirements.md       # 要件定義書（Gemini作成）
├── external_spec.md      # 外部仕様書（Gemini作成）
├── detailed_spec.md      # 詳細仕様書（Claude作成）
├── unit_test_plan.md     # 単体テスト計画書
└── integration_test_plan.md  # 統合テスト計画書

src/
└── [実装されたソースコード]

tests/
└── [テストコード]
```

## 利点と制限事項

### 利点

- **客観的な品質保証**：異なるAIによるクロスレビュー
- **明確な責任分担**：各フェーズでの役割が明確
- **自動化された管理**：進捗と使用量の自動監視

### 制限事項

- Claude APIの使用量制限（1日あたりの上限）
- Gemini MCPのセットアップが必要
- tmux環境が必須

## 今後の展望

1. **より柔軟な役割設定**
   - プロジェクトに応じた動的な役割変更

2. **他のAIモデルへの対応**
   - GPT-4やその他のモデルとの協調

3. **自動化の拡張**
   - テスト実行やデプロイの自動化

## まとめ

autodevgは、複数のAIモデルを協調させることで、単一のAIでは実現できない品質と効率を目指したシステムです。特に、異なる視点からのレビューと明確な役割分担により、より堅牢な開発プロセスを実現できます。

オープンソースとして公開していますが、プルリクエストやIssueをいただいても対応できませんので、ご自由にフォークしてご使用ください。

## リンク

- [GitHub リポジトリ](https://github.com/tokumeishatyo/autodevg)
- [Claude API](https://www.anthropic.com/api)
- [Gemini API](https://ai.google.dev/)

## ライセンス

MIT License