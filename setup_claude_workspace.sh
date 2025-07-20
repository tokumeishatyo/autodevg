#!/bin/bash

# Create new tmux session with 2x2 grid layout for autodevg
tmux new-session -d -s autodevg_workspace

# Create 2x2 grid
# First split horizontally to create 2 columns
tmux split-window -h -p 50  # Create right half

# Now split each column vertically
tmux select-pane -t 0
tmux split-window -v -p 50  # Split left column
tmux select-pane -t 2
tmux split-window -v -p 50  # Split right column

# Final 2x2 layout:
# 0: Manager (top-left)        2: Progress Monitor (top-right)
# 1: Developer (bottom-left)   3: Usage Monitor (bottom-right)

# Set pane titles and colors (eye-friendly dark backgrounds)
# Manager (top-left) - Dark orange/amber
tmux select-pane -t 0
tmux send-keys "echo 'Manager Pane (CEO統合)'" C-m
tmux select-pane -P 'bg=#1f1611,fg=#ffb366'

# Developer (bottom-left) - Dark green
tmux select-pane -t 1
tmux send-keys "echo 'Developer Pane'" C-m
tmux select-pane -P 'bg=#0d1b0d,fg=#90ee90'

# Progress Monitor (top-right) - Dark gray/white
tmux select-pane -t 2
tmux send-keys "echo 'Progress Monitor'" C-m
tmux select-pane -P 'bg=#1c1c1c,fg=#ffffff'

# Usage Monitor (bottom-right) - Dark yellow/gold
tmux select-pane -t 3
tmux send-keys "echo 'Usage Monitor'" C-m
tmux select-pane -P 'bg=#1f1f0a,fg=#ffd700'

# Start Claude with Sonnet model in Manager pane
tmux select-pane -t 0
tmux send-keys "claude --dangerously-skip-permissions --model sonnet" C-m
sleep 3  # Wait for permissions prompt to appear
tmux send-keys "2" C-m  # Select option 2 (Continue) instead of 1 (Exit)
sleep 5  # Wait for Claude to start properly
tmux send-keys "cat WorkFlow/instructions_manager.md"
tmux send-keys C-m
sleep 5
tmux send-keys "cat WorkFlow/planning.txt"
tmux send-keys C-m
sleep 5
# Ensure Japanese language setting for Manager pane
tmux send-keys "必ず日本語で回答してください。"
tmux send-keys C-m
sleep 5

# Start Claude with Opus model in Developer pane
tmux select-pane -t 1
tmux send-keys "claude --dangerously-skip-permissions --model opus" C-m
sleep 3  # Wait for permissions prompt to appear
tmux send-keys "2" C-m  # Select option 2 (Continue) instead of 1 (Exit)
sleep 5  # Wait for Claude to start properly
tmux send-keys "cat WorkFlow/instructions_developer.md"
tmux send-keys C-m
sleep 5
# Ensure Japanese language setting for Developer pane
tmux send-keys "必ず日本語で回答してください。"
tmux send-keys C-m
sleep 5

# Wait for all Claude instances to be ready
sleep 5

# Start progress monitor in dedicated pane (pane 2)
tmux select-pane -t 2
tmux send-keys "./scripts/progress_monitor.sh" C-m
sleep 2

# Initialize usage monitoring system
echo "📊 使用量監視システムを初期化しています..."
./scripts/check_claude_usage.sh >/dev/null 2>&1

# Start usage monitor in dedicated pane (pane 3)
tmux select-pane -t 3
tmux send-keys "./scripts/usage_monitor_display.sh monitor" C-m
sleep 2

# Focus on Manager pane (ready state)
tmux select-pane -t 0

# Send initial setup message to Manager to prepare for /go command
sleep 5  # Wait for all panes to be ready
tmux send-keys "システムの準備が完了しました。/goコマンドが発令されたら、planning.txtを読み込んで開発プロセスを開始します。/goコマンドを入力してください。"
tmux send-keys C-m

# Setup cleanup on exit
trap './scripts/cleanup_progress.sh' EXIT

# Attach to the session
tmux attach-session -t autodevg_workspace

# Cleanup on session end
./scripts/cleanup_progress.sh