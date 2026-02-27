#!/bin/bash

# AI 知识库文档管理脚本
# 用法：./manage-docs.sh [add|commit|push|sync|status] "提交信息"

REPO_DIR="/Users/eddy/.openclaw/workspace/ai-knowledge-base"
OBSIDIAN_DIR="/Users/eddy/Library/Mobile Documents/iCloud~md~obsidian/Documents/EddyVailt"
REMOTE_URL="https://github.com/qudi17/ai-knowledge-base.git"

cd "$REPO_DIR" || exit 1

log() {
    echo "[$(date +%H:%M:%S)] $1"
}

case "${1:-status}" in
  add)
    log "📝 添加文件变更..."
    git add -A
    git status --short
    ;;
    
  commit)
    message="${2:-自动更新：$(date +%Y-%m-%d %H:%M)}"
    log "💾 提交：$message"
    git add -A
    git commit -m "$message"
    ;;
    
  push)
    log "📤 推送到 GitHub..."
    git add -A
    status=$(git status --porcelain)
    if [ -n "$status" ]; then
      message="${2:-自动更新：$(date +%Y-%m-%d %H:%M)}"
      git commit -m "$message"
    fi
    git push "$REMOTE_URL" main
    if [ $? -eq 0 ]; then
      log "✅ 推送成功！"
    else
      log "❌ 推送失败，请检查网络连接或 GitHub 凭证"
      exit 1
    fi
    ;;
    
  sync)
    log "🔄 同步到 Obsidian..."
    
    # 先推送到 GitHub
    "$0" push
    
    # 然后同步到 Obsidian
    log "📥 复制到 Obsidian..."
    cp -R "📰 技术博客追踪/"* "$OBSIDIAN_DIR/📰 技术博客追踪/" 2>/dev/null || true
    cp -R "🔧 技术专项/"* "$OBSIDIAN_DIR/🔧 技术专项/" 2>/dev/null || true
    cp "README.md" "$OBSIDIAN_DIR/" 2>/dev/null || true
    cp "SETUP.md" "$OBSIDIAN_DIR/" 2>/dev/null || true
    
    log "✅ 同步完成！"
    ;;
    
  status)
    log "📊 仓库状态"
    echo ""
    echo "远程仓库：$REMOTE_URL"
    echo ""
    
    git remote -v
    echo ""
    
    git status --short
    echo ""
    
    log "最近提交："
    git log --oneline -5
    echo ""
    
    log "文件统计："
    echo "  📰 技术博客追踪：$(find "📰 技术博客追踪" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') 篇"
    echo "  🔧 技术专项：$(find "🔧 技术专项" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ') 篇"
    ;;
    
  *)
    echo "用法：$0 [add|commit|push|sync|status] [提交信息]"
    echo ""
    echo "  add    - 添加文件变更"
    echo "  commit - 提交到本地仓库"
    echo "  push   - 推送到 GitHub"
    echo "  sync   - 推送到 GitHub 并同步到 Obsidian"
    echo "  status - 查看状态"
    ;;
esac
