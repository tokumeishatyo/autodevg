#!/bin/bash
# Gemini役割制限検証スクリプト
# Usage: ./scripts/validate_gemini_role.sh [PHASE] [TASK_TYPE]

CURRENT_PHASE="$1"
TASK_TYPE="$2"
SHARED_DIR="/tmp/autodevg_status"

# 共有ディレクトリを作成
mkdir -p "$SHARED_DIR"

# Phase情報を保存
echo "$CURRENT_PHASE" > "$SHARED_DIR/current_phase.txt"

# 日本時間の取得
JST_TIME=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')

# 役割制限チェック関数
check_gemini_permission() {
    local phase="$1"
    local task="$2"
    
    case "$phase" in
        "requirements"|"phase1"|"Phase1")
            case "$task" in
                "create_requirements"|"create_external_spec"|"要件定義"|"外部仕様")
                    echo "ALLOWED"
                    return 0
                    ;;
                "review"|"レビュー")
                    echo "ALLOWED"
                    return 0
                    ;;
                *)
                    echo "REVIEW_ONLY"
                    return 1
                    ;;
            esac
            ;;
        "detailed_spec"|"phase2"|"Phase2"|"implementation"|"phase3"|"Phase3")
            case "$task" in
                "review"|"レビュー")
                    echo "ALLOWED"
                    return 0
                    ;;
                *)
                    echo "FORBIDDEN"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "REVIEW_ONLY"
            return 1
            ;;
    esac
}

# 使用方法チェック
if [ -z "$CURRENT_PHASE" ] || [ -z "$TASK_TYPE" ]; then
    echo "使用方法: $0 [PHASE] [TASK_TYPE]"
    echo ""
    echo "Phase例:"
    echo "  requirements  - 要件定義・外部仕様作成段階"
    echo "  detailed_spec - 詳細仕様作成段階"
    echo "  implementation - 実装段階"
    echo ""
    echo "Task例:"
    echo "  create_requirements - 要件定義書作成"
    echo "  create_external_spec - 外部仕様書作成"
    echo "  review - レビュー・評価"
    echo "  edit_detailed_spec - 詳細仕様書編集"
    echo "  edit_code - コード編集"
    exit 1
fi

# 権限チェック実行
PERMISSION_RESULT=$(check_gemini_permission "$CURRENT_PHASE" "$TASK_TYPE")
CHECK_RESULT=$?

# 結果に基づくメッセージ出力
echo "=== Gemini役割制限チェック結果 ==="
echo "📅 チェック時刻: $JST_TIME"
echo "🔄 現在のPhase: $CURRENT_PHASE"
echo "📋 要求作業: $TASK_TYPE"
echo "🎯 判定結果: $PERMISSION_RESULT"
echo "================================"

case "$PERMISSION_RESULT" in
    "ALLOWED")
        echo "✅ 許可: Geminiによる作業実行が可能です"
        # 許可プロンプトファイルの作成
        cat > "$SHARED_DIR/gemini_prompt_template.txt" << EOF
【承認済み作業依頼】
Phase: $CURRENT_PHASE
作業種別: $TASK_TYPE
実行時刻: $JST_TIME

以下の作業を実行してください：
[作業内容を記載]
EOF
        ;;
    "REVIEW_ONLY")
        echo "⚠️ 制限: レビュー作業のみ許可されています"
        # レビュー専用プロンプトファイルの作成
        cat > "$SHARED_DIR/gemini_prompt_template.txt" << EOF
【レビュー依頼のみ】
Phase: $CURRENT_PHASE
実行時刻: $JST_TIME

以下の文書をレビューしてください。問題点や改善点を指摘してください。
⚠️ 注意：編集や書き直しは行わず、レビューコメントのみ提供してください。

[レビュー対象文書の内容]
EOF
        ;;
    "FORBIDDEN")
        echo "🚫 禁止: 現在のPhaseでは該当作業は禁止されています"
        # 禁止警告ファイルの作成
        cat > "$SHARED_DIR/gemini_warning.txt" << EOF
🚨 Gemini役割制限警告
現在のPhase: $CURRENT_PHASE
制限内容: Geminiによる文書編集は禁止されています
許可作業: レビュー・評価・指摘の提供のみ
対応方法: Developer自身が修正を実施してください
EOF
        ;;
esac

# ログ記録
echo "[$JST_TIME] Gemini役割制限チェック: Phase=$CURRENT_PHASE, Task=$TASK_TYPE, Result=$PERMISSION_RESULT" >> "$SHARED_DIR/gemini_role_log.txt"

# 終了コード
exit $CHECK_RESULT