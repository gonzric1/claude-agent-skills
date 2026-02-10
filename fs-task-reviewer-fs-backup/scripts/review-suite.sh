#!/bin/bash
# scripts/review-suite.sh - Automated Quality Check for Ruby & TypeScript

echo "--- SENIOR REVIEWER: RUNNING AUDIT ---"

# 1. Ruby / Rails Audit
if [ -f "Gemfile" ]; then
  echo "[Audit] Checking Ruby Style & Safety..."
  bundle exec rubocop --parallel
  bundle exec brakeman -q
  
  if [ -d "coverage" ]; then
    echo "[Audit] Ruby Coverage data detected."
  else
    echo "[Warning] No Ruby coverage report. Run 'COVERAGE=true bundle exec rspec' first."
  fi
fi

# 2. TypeScript / Frontend Audit
if [ -f "package.json" ]; then
  echo "[Audit] Checking TypeScript Quality..."
  npx eslint 'app/javascript/**/*.{ts,tsx}' --max-warnings 150
  npx tsc --noEmit
  
  if [ -d "coverage" ]; then
    echo "[Audit] TS Coverage data detected."
  fi
fi

echo "--- AUDIT COMPLETE ---"