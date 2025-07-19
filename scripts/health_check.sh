#!/bin/bash

# システム生存確認・復旧スクリプト
# Manager主導で他のペインの生存確認を行う

# 設定
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$WORKSPACE_DIR/logs/health_check.log"
STATE_FILE="$WORKSPACE_DIR/tmp/system_state.txt"
TMUX_SESSION="autodevg_workspace"

# 日本時間で現在時刻を取得
current_time() {
    TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'
}

# ログ出力
log_message() {
    echo "[$(current_time)] $1" | tee -a "$LOG_FILE"
}

# システム状態を取得
get_system_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "normal"
    fi
}

# システム状態を設定
set_system_state() {
    echo "$1" > "$STATE_FILE"
    log_message "システム状態を$1に変更"
}

# tmuxセッションの生存確認
check_tmux_session() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 各ペインの生存確認（2x2構成対応）
check_pane() {
    local pane_id="$1"
    local pane_name="$2"
    
    if tmux list-panes -t "$TMUX_SESSION" | grep -q "^$pane_id:"; then
        log_message "$pane_name ペイン: 生存確認OK"
        return 0
    else
        log_message "$pane_name ペイン: 生存確認NG"
        return 1
    fi
}

# 待機モードかどうかの判定
is_standby_mode() {
    local state=$(get_system_state)
    if [ "$state" = "standby" ]; then
        return 0
    else
        return 1
    fi
}

# 復旧処理（2x2構成対応）
recover_system() {
    local state=$(get_system_state)
    
    if is_standby_mode; then
        log_message "待機モード中のため、復旧は手動で行ってください (/restart)"
        return 1
    fi
    
    log_message "システム復旧を開始"
    
    # tmuxセッションの復旧
    if ! check_tmux_session; then
        log_message "tmuxセッションを復旧中..."
        
        # 既存のセッションを終了
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
        
        # 新しいセッションを作成（2x2構成）
        tmux new-session -d -s "$TMUX_SESSION" -x 120 -y 40
        
        # ペインを分割（2x2構成）
        tmux split-window -h -t "$TMUX_SESSION"     # 左右分割
        tmux split-window -v -t "$TMUX_SESSION:0.0" # 左上下分割
        tmux split-window -v -t "$TMUX_SESSION:0.2" # 右上下分割
        
        # ペインの色設定
        tmux select-pane -t "$TMUX_SESSION:0.0" -P 'bg=colour220,fg=black'  # Manager: オレンジ
        tmux select-pane -t "$TMUX_SESSION:0.1" -P 'bg=colour28,fg=white'   # Developer: 緑
        tmux select-pane -t "$TMUX_SESSION:0.2" -P 'bg=colour21,fg=white'   # Progress: 青
        tmux select-pane -t "$TMUX_SESSION:0.3" -P 'bg=colour52,fg=white'   # Usage: 茶
        
        # 各ペインを適切なディレクトリに移動
        tmux send-keys -t "$TMUX_SESSION:0.0" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$TMUX_SESSION:0.1" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$TMUX_SESSION:0.2" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$TMUX_SESSION:0.3" "cd $WORKSPACE_DIR" C-m
        
        # 各ペインの役割を設定
        tmux send-keys -t "$TMUX_SESSION:0.0" "echo 'Manager ペイン復旧完了 (2x2構成)'" C-m
        tmux send-keys -t "$TMUX_SESSION:0.1" "echo 'Developer ペイン復旧完了 (2x2構成)'" C-m
        tmux send-keys -t "$TMUX_SESSION:0.2" "echo 'Progress Monitor ペイン復旧完了'" C-m
        tmux send-keys -t "$TMUX_SESSION:0.3" "echo 'Usage Monitor ペイン復旧完了'" C-m
        
        sleep 2
        
        # 復旧後の確認
        if check_tmux_session; then
            log_message "tmuxセッション復旧成功"
            return 0
        else
            log_message "tmuxセッション復旧失敗"
            return 1
        fi
    else
        log_message "tmuxセッションは正常です"
        return 0
    fi
}

# 生存確認実行（2x2構成対応）
perform_health_check() {
    log_message "=== 生存確認開始 (2x2構成) ==="
    
    local all_ok=true
    
    # tmuxセッションの確認
    if ! check_tmux_session; then
        log_message "tmuxセッション: 生存確認NG"
        all_ok=false
    else
        log_message "tmuxセッション: 生存確認OK"
        
        # 各ペインの確認（2x2構成）
        check_pane "0" "Manager" || all_ok=false
        check_pane "1" "Developer" || all_ok=false  
        check_pane "2" "Progress Monitor" || all_ok=false
        check_pane "3" "Usage Monitor" || all_ok=false
    fi
    
    if $all_ok; then
        log_message "全システム正常"
        return 0
    else
        log_message "システム異常を検出"
        return 1
    fi
}

# メイン処理
main() {
    # ログディレクトリの作成
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$STATE_FILE")"
    
    # 引数による処理分岐
    case "${1:-check}" in
        "check")
            perform_health_check
            ;;
        "recover")
            if perform_health_check; then
                log_message "システム正常のため復旧不要"
            else
                recover_system
            fi
            ;;
        "standby")
            set_system_state "standby"
            log_message "待機モードに移行"
            ;;
        "restart")
            set_system_state "normal"
            log_message "通常モードに復帰"
            recover_system
            ;;
        *)
            echo "使用法: $0 {check|recover|standby|restart}"
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"