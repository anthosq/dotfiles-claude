#!/usr/bin/bash
# Shim for `grep -P` on Windows/MSYS2 where the bundled GNU grep 3.0
# was compiled without working PCRE support.
#
# Detects the defect once at source-time; if broken, defines a `grep()`
# bash function that intercepts -P/-qP/-oP calls and delegates to perl
# (bundled with Git for Windows). Non-P calls pass through to real grep.
#
# Source this file early in any hook that uses `grep -P`:
#   source "$(dirname "$0")/lib/pcre-compat.sh"

if ! command grep -qP 'x' <<< 'x' 2>/dev/null; then
    grep() {
        local has_P=false
        for _a in "$@"; do
            case "$_a" in
                -P|-qP|-Pq|-oP|-Po) has_P=true; break ;;
                -*P*) has_P=true; break ;;
            esac
        done

        if ! $has_P; then
            command grep "$@"
            return
        fi

        # Parse flags
        local quiet=false only_matching=false pattern="" files=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -q)       quiet=true ;;
                -o)       only_matching=true ;;
                -P)       ;;
                -qP|-Pq)  quiet=true ;;
                -oP|-Po)  only_matching=true ;;
                -*)       # combined flags: strip P, parse q/o
                          [[ "$1" == *q* ]] && quiet=true
                          [[ "$1" == *o* ]] && only_matching=true ;;
                *)        if [ -z "$pattern" ]; then pattern="$1"
                          else files+=("$1"); fi ;;
            esac
            shift
        done

        # Delegate to perl via env var (avoids escaping issues)
        if $quiet; then
            PCRE_PAT="$pattern" perl -ne \
                'BEGIN{$r=1} if(/$ENV{PCRE_PAT}/){$r=0;exit} END{exit $r}' \
                ${files[@]+"${files[@]}"}
        elif $only_matching; then
            PCRE_PAT="$pattern" perl -ne \
                'while (/$ENV{PCRE_PAT}/g) { print $&, "\n" }' \
                ${files[@]+"${files[@]}"}
        else
            PCRE_PAT="$pattern" perl -ne \
                'print if /$ENV{PCRE_PAT}/' \
                ${files[@]+"${files[@]}"}
        fi
    }
fi
