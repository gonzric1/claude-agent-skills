#!/bin/bash
# scripts/review-suite.sh - Automated Quality Check for Ruby & TypeScript

set -e  # Exit on first error
FAILURES=0

echo "=========================================="
echo "  SENIOR REVIEWER: RUNNING AUDIT"
echo "=========================================="
echo ""

# 1. Ruby / Rails Audit
if [ -f "Gemfile" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  RUBY / RAILS AUDIT"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Style check
  echo "[1/4] Checking Ruby Style (RuboCop)..."
  if bundle exec rubocop --parallel; then
    echo "✓ RuboCop passed"
  else
    echo "✗ RuboCop found issues"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Security check
  echo "[2/4] Checking Security (Brakeman)..."
  if bundle exec brakeman -q; then
    echo "✓ Brakeman passed (no security issues)"
  else
    echo "✗ Brakeman found security issues"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Run tests with coverage
  echo "[3/4] Running Ruby Tests with Coverage..."
  if COVERAGE=true bundle exec rails test; then
    echo "✓ Ruby tests passed"
  else
    echo "✗ Ruby tests failed"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Parse coverage report
  echo "[4/4] Analyzing Ruby Coverage..."
  if [ -f "coverage/.resultset.json" ]; then
    # Extract line coverage from SimpleCov .resultset.json using ResultMerger
    RUBY_LINE_COV=$(ruby -rsimplecov -e "SimpleCov.coverage_dir('coverage'); result = SimpleCov::ResultMerger.merged_result; puts result ? result.covered_percent.round(2) : 'N/A'" 2>/dev/null || echo "N/A")

    # Extract branch coverage - try .last_run.json first (simpler), fallback to manual parsing
    RUBY_BRANCH_COV=$(ruby -rjson -e "
      if File.exist?('coverage/.last_run.json')
        data = JSON.parse(File.read('coverage/.last_run.json'))
        puts data.dig('result', 'branch')&.round(2) || 'N/A'
      else
        # Fallback: manually calculate from .resultset.json
        data = JSON.parse(File.read('coverage/.resultset.json'))
        total = 0
        covered = 0
        data.each do |_, info|
          next unless info['coverage']
          info['coverage'].each do |_, cov|
            next unless cov['branches']
            cov['branches'].each do |_, targets|
              targets.each do |_, count|
                total += 1
                covered += 1 if count && count > 0
              end
            end
          end
        end
        puts total > 0 ? ((covered.to_f / total * 100).round(2)) : 'N/A'
      end
    " 2>/dev/null || echo "N/A")

    echo "┌────────────────────────────────────┐"
    echo "│  Ruby Coverage Report              │"
    echo "├────────────────────────────────────┤"
    echo "│  Line Coverage:   ${RUBY_LINE_COV}%"
    echo "│  Branch Coverage: ${RUBY_BRANCH_COV}%"
    echo "└────────────────────────────────────┘"

    # Check thresholds (80% line, 75% branch)
    if [ "$RUBY_LINE_COV" != "N/A" ]; then
      if (( $(echo "$RUBY_LINE_COV < 80" | bc -l) )); then
        echo "⚠  Warning: Line coverage below 80% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi

    if [ "$RUBY_BRANCH_COV" != "N/A" ]; then
      if (( $(echo "$RUBY_BRANCH_COV < 75" | bc -l) )); then
        echo "⚠  Warning: Branch coverage below 75% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi
  else
    echo "⚠  Warning: No coverage report found"
    echo "   Coverage report should be at: coverage/.resultset.json"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""
fi

# 2. TypeScript / Frontend Audit
if [ -f "package.json" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  TYPESCRIPT / FRONTEND AUDIT"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Lint check
  echo "[1/4] Checking TypeScript Style (ESLint)..."
  if npx eslint 'app/javascript/**/*.{ts,tsx}' --max-warnings 150; then
    echo "✓ ESLint passed"
  else
    echo "✗ ESLint found issues"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Type check
  echo "[2/4] Checking TypeScript Types..."
  if npx tsc --noEmit; then
    echo "✓ TypeScript compilation passed"
  else
    echo "✗ TypeScript compilation failed"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Run tests with coverage
  echo "[3/4] Running Frontend Tests with Coverage..."
  if npm test -- run --coverage; then
    echo "✓ Frontend tests passed"
  else
    echo "✗ Frontend tests failed"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""

  # Parse coverage report
  echo "[4/4] Analyzing Frontend Coverage..."
  if [ -f "coverage/coverage-summary.json" ]; then
    # Extract coverage from Vitest JSON report
    TS_LINE_COV=$(node -e "const data = require('./coverage/coverage-summary.json'); console.log(data.total.lines.pct)" 2>/dev/null || echo "N/A")
    TS_BRANCH_COV=$(node -e "const data = require('./coverage/coverage-summary.json'); console.log(data.total.branches.pct)" 2>/dev/null || echo "N/A")
    TS_FUNC_COV=$(node -e "const data = require('./coverage/coverage-summary.json'); console.log(data.total.functions.pct)" 2>/dev/null || echo "N/A")
    TS_STMT_COV=$(node -e "const data = require('./coverage/coverage-summary.json'); console.log(data.total.statements.pct)" 2>/dev/null || echo "N/A")

    echo "┌────────────────────────────────────┐"
    echo "│  Frontend Coverage Report          │"
    echo "├────────────────────────────────────┤"
    echo "│  Line Coverage:      ${TS_LINE_COV}%"
    echo "│  Branch Coverage:    ${TS_BRANCH_COV}%"
    echo "│  Function Coverage:  ${TS_FUNC_COV}%"
    echo "│  Statement Coverage: ${TS_STMT_COV}%"
    echo "└────────────────────────────────────┘"

    # Check thresholds (defined in vitest.config.ts)
    if [ "$TS_LINE_COV" != "N/A" ]; then
      if (( $(echo "$TS_LINE_COV < 80" | bc -l) )); then
        echo "⚠  Warning: Line coverage below 80% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi

    if [ "$TS_BRANCH_COV" != "N/A" ]; then
      if (( $(echo "$TS_BRANCH_COV < 75" | bc -l) )); then
        echo "⚠  Warning: Branch coverage below 75% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi

    if [ "$TS_FUNC_COV" != "N/A" ]; then
      if (( $(echo "$TS_FUNC_COV < 80" | bc -l) )); then
        echo "⚠  Warning: Function coverage below 80% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi

    if [ "$TS_STMT_COV" != "N/A" ]; then
      if (( $(echo "$TS_STMT_COV < 80" | bc -l) )); then
        echo "⚠  Warning: Statement coverage below 80% threshold"
        FAILURES=$((FAILURES + 1))
      fi
    fi
  else
    echo "⚠  Warning: No coverage report found"
    echo "   Coverage report should be at: coverage/coverage-summary.json"
    FAILURES=$((FAILURES + 1))
  fi
  echo ""
fi

echo "=========================================="
if [ $FAILURES -eq 0 ]; then
  echo "  ✓ AUDIT COMPLETE - ALL CHECKS PASSED"
  echo "=========================================="
  exit 0
else
  echo "  ✗ AUDIT COMPLETE - $FAILURES ISSUE(S) FOUND"
  echo "=========================================="
  exit 1
fi