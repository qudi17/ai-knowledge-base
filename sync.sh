#!/bin/bash

# Obsidian ↔ GitHub 双向同步脚本
# 用法：./sync.sh [push|pull|status]

REPO_DIR="/Users/eddy/.openclaw/workspace/ai-knowledge-base"
OBSIDIAN_DIR="/Users/eddy/Library/Mobile Documents/iCloud~md~obsidian/Documents/EddyVailt"

cd "$REPO_DIR" || exit 1

case "${1:-status}" in
  push)
    echo "📤 推送到 GitHub..."
    
    # 从 Obsidian 复制最新文件
    cp -R "$OBSIDIAN_DIR/📰 技术博客追踪/"* "📰 技术博客追踪/" 2>/dev/null || true
    cp -R "$OBSIDIAN_DIR/🔧 技术专项/"* "🔧 技术专项/" 2>/dev/null || true
    
    # Git 操作
    git add .
    git status
    read -p "输入提交信息 (默认：自动同步): " message
    message=${message:-"自动同步：$(date +%Y-%m-%d %H:%M)"}
    git commit -m "$message"
    git push
    
    echo "✅ 推送完成！"
    ;;
    
  pull)
    echo "📥 从 GitHub 拉取..."
    
    git pull origin main
    
    # 同步到 Obsidian
    cp -R "📰 技术博客追踪/"* "$OBSIDIAN_DIR/📰 技术博客追踪/" 2>/dev/null || true
    cp -R "🔧 技术专项/"* "$OBSIDIAN_DIR/🔧 技术专项/" 2>/dev/null || true
    
    echo "✅ 拉取完成！"
    ;;
    
  status)
    echo "📊 同步状态"
    echo ""
    echo "仓库目录：$REPO_DIR"
    echo "Obsidian 目录：$OBSIDIAN_DIR"
    echo ""
    
    echo "=== Git 状态 ==="
    git status --short
    echo ""
    
    echo "=== 最近提交 ==="
    git log --oneline -5
    echo ""
    
    echo "=== Markdown 文件统计 ==="
    echo "技术博客追踪：$(find "📰 技术博客追踪" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') 篇"
    echo "技术专项：$(find "🔧 技术专项" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') 篇"
    ;;
    
  *)
    echo "用法：$0 [push|pull|status]"
    echo ""
    echo "  push   - 推送到 GitHub"
    echo "  pull   - 从 GitHub 拉取"
    echo "  status - 查看同步状态"
    ;;
esac
