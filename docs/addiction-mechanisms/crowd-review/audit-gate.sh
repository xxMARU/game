#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 众包评审审计门禁脚本
# 作用：验证每一步操作确实产生了文件输出，防止主session幻觉
# ═══════════════════════════════════════════════════════════════

REVIEW_DIR="$HOME/Desktop/addiction-research/crowd-review"
AUDIT_LOG="$REVIEW_DIR/audit-log.md"

# 初始化审计日志
init_audit() {
    cat > "$AUDIT_LOG" << 'EOF'
# 众包评审审计日志

> 本日志自动记录所有评审操作，由audit-gate.sh生成。
> 任何未通过门禁检查的步骤会被标记为 ❌ FAIL。

---

EOF
    echo "$(date '+%Y-%m-%d %H:%M:%S') | INIT | 审计系统初始化" >> "$AUDIT_LOG"
}

# 记录操作
log_action() {
    local phase="$1"
    local action="$2"
    local detail="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $phase | $action | $detail" >> "$AUDIT_LOG"
}

# 门禁检查：验证文件存在且非空
gate_check() {
    local phase="$1"
    local expected_file="$2"
    local description="$3"
    
    if [ -f "$expected_file" ]; then
        local size=$(wc -c < "$expected_file" | tr -d ' ')
        if [ "$size" -gt 100 ]; then
            echo "✅ PASS | $description | $(basename $expected_file) | ${size} bytes"
            log_action "$phase" "✅ PASS" "$description | $(basename $expected_file) | ${size} bytes"
            return 0
        else
            echo "❌ FAIL | $description | 文件过小(${size}bytes)，可能为空壳"
            log_action "$phase" "❌ FAIL" "$description | 文件过小(${size}bytes)"
            return 1
        fi
    else
        echo "❌ FAIL | $description | 文件不存在: $(basename $expected_file)"
        log_action "$phase" "❌ FAIL" "$description | 文件不存在"
        return 1
    fi
}

# 检查某轮评审的所有必要文件
check_round() {
    local round_num="$1"  # 1, 2, 3, or final
    local round_dir="$REVIEW_DIR/round-${round_num}"
    local pass_count=0
    local fail_count=0
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  检查 Round $round_num 完整性"
    echo "═══════════════════════════════════════"
    
    # 检查独立评审文件
    for agent in A B C D E; do
        if gate_check "R${round_num}" "${round_dir}/independent/agent-${agent}-review.md" "Agent-${agent}独立评审"; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done
    
    # 检查辩论文件（至少需要有几轮）
    local debate_dir="${round_dir}/debate"
    if [ -d "$debate_dir" ]; then
        local debate_files=$(ls "$debate_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
        if [ "$debate_files" -ge 3 ]; then
            echo "✅ PASS | 辩论文件 | ${debate_files} 个辩论文件"
            log_action "R${round_num}" "✅ PASS" "辩论文件 | ${debate_files}个"
            ((pass_count++))
        else
            echo "❌ FAIL | 辩论文件 | 仅 ${debate_files} 个，不足3轮"
            log_action "R${round_num}" "❌ FAIL" "辩论文件不足"
            ((fail_count++))
        fi
    else
        echo "❌ FAIL | 辩论目录不存在"
        log_action "R${round_num}" "❌ FAIL" "辩论目录不存在"
        ((fail_count++))
    fi
    
    # 检查共识文件
    if gate_check "R${round_num}" "${round_dir}/consensus.md" "共识方案"; then
        ((pass_count++))
    else
        ((fail_count++))
    fi
    
    echo "---"
    echo "  结果: ✅ ${pass_count} 通过 | ❌ ${fail_count} 失败"
    log_action "R${round_num}" "SUMMARY" "✅${pass_count} ❌${fail_count}"
    
    if [ "$fail_count" -gt 0 ]; then
        return 1
    fi
    return 0
}

# 完整流程检查
full_check() {
    echo "╔═══════════════════════════════════════════╗"
    echo "║     众包评审完整性审计报告                  ║"
    echo "║     $(date '+%Y-%m-%d %H:%M:%S')              ║"
    echo "╚═══════════════════════════════════════════╝"
    
    # 检查背景文档
    gate_check "INIT" "$REVIEW_DIR/00-background.md" "背景文档"
    
    # 检查三轮评审
    for round in 1 2 3; do
        check_round "$round"
    done
    
    # 检查终极评审
    check_round "final"
    
    # 检查最终输出
    gate_check "OUTPUT" "$REVIEW_DIR/final-consensus.md" "终极共识方案"
}

# 根据参数执行不同操作
case "$1" in
    init)
        init_audit
        ;;
    check-file)
        gate_check "$2" "$3" "$4"
        ;;
    check-round)
        check_round "$2"
        ;;
    full-check)
        full_check
        ;;
    log)
        log_action "$2" "$3" "$4"
        ;;
    *)
        echo "Usage: $0 {init|check-file|check-round|full-check|log}"
        echo "  init                     - 初始化审计日志"
        echo "  check-file PHASE FILE DESC - 检查单个文件"
        echo "  check-round NUM          - 检查某轮完整性(1/2/3/final)"
        echo "  full-check               - 完整审计"
        echo "  log PHASE ACTION DETAIL  - 记录日志"
        ;;
esac
