#!/bin/bash
# 作業種別自動検出スクリプト

detect_work_type() {
    local message="$1"
    local source_pane="$2"
    local target_pane="$3"
    
    # メッセージの内容から作業種別を推定
    if echo "$message" | grep -iE "(思考|考慮|検討|判断)" >/dev/null; then
        echo "thinking"
    elif echo "$message" | grep -iE "(文書|仕様書|要件|企画|計画)" >/dev/null; then
        echo "document_creation"
    elif echo "$message" | grep -iE "(コード|実装|開発|プログラム)" >/dev/null; then
        echo "code_development"
    elif echo "$message" | grep -iE "(レビュー|チェック|確認|検査)" >/dev/null; then
        echo "code_review"
    elif echo "$message" | grep -iE "(テスト|試験|動作確認)" >/dev/null; then
        echo "testing"
    elif echo "$message" | grep -iE "(分析|解析|調査|調べ)" >/dev/null; then
        echo "analysis"
    elif echo "$message" | grep -iE "(仕様|設計|アーキテクチャ)" >/dev/null; then
        echo "specification"
    elif echo "$message" | grep -iE "(計画|企画|スケジュール)" >/dev/null; then
        echo "planning"
    else
        # ペインに基づく既定値
        case "$target_pane" in
            0) echo "thinking" ;;      # CEO
            1) echo "planning" ;;      # Manager  
            2) echo "code_review" ;;   # Reviewer
            3) echo "code_development" ;; # Developer
            *) echo "thinking" ;;
        esac
    fi
}

# コマンドライン実行時
if [ $# -ge 1 ]; then
    detect_work_type "$1" "$2" "$3"
fi