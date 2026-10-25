#!/usr/bin/env bash
# Prints a tmux-format git segment, or nothing if not inside a git work tree.
# Usage: git_status.sh <branch|changes> <dir>
mode="$1"
dir="$2"
cd "$dir" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

case "$mode" in
branch)
	branch=$(git symbolic-ref --short HEAD 2>/dev/null)
	[ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)
	printf '#[fg=#89b4fa,bold]%s#[default]' "$branch"
	;;
changes)
	staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
	unstaged=$(git diff --name-only 2>/dev/null | wc -l)
	untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

	out=""
	[ "$staged" -gt 0 ] && out="${out}#[fg=#a6e3a1]+${staged}#[default] "
	[ "$unstaged" -gt 0 ] && out="${out}#[fg=#f9e2af]~${unstaged}#[default] "
	[ "$untracked" -gt 0 ] && out="${out}#[fg=#94e2d5]?${untracked}#[default] "
	printf '%s' "$out"
	;;
esac
