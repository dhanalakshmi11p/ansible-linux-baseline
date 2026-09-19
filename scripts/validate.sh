#!/usr/bin/env bash
#
# validate.sh - read-only check of the SSH and user baseline on this server.
# Makes no changes. Run it before and after the playbook to see the difference.
#
# Usage: sudo ./scripts/validate.sh [username]      (default user: opsuser)
# Exit code: 0 if every check passes, 1 if any check fails, 2 if sshd is missing.

set -u

USER_TO_CHECK=${1:-opsuser}
pass=0
fail=0

check() {
  # usage: check <description> <expected> <actual>
  if [[ "$3" == "$2" ]]; then
    printf 'PASS  %-26s %s\n' "$1" "$3"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-26s expected %s, got %s\n' "$1" "$2" "${3:-<none>}"
    fail=$((fail + 1))
  fi
}

echo "Host: $(hostname)    Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "--------------------------------------------------------------"

if ! command -v sshd >/dev/null 2>&1; then
  echo "sshd not found on this host"
  exit 2
fi

sshd_out=$(sshd -T 2>/dev/null)
get() { awk -v k="$1" '$1 == k { print $2; exit }' <<<"$sshd_out"; }

check "PermitRootLogin" "no" "$(get permitrootlogin)"
check "X11Forwarding" "no" "$(get x11forwarding)"
check "MaxAuthTries" "4" "$(get maxauthtries)"
check "ClientAliveInterval" "300" "$(get clientaliveinterval)"
check "ClientAliveCountMax" "2" "$(get clientalivecountmax)"

if [[ -f /etc/ssh/sshd_config.d/00-hardening.conf ]]; then dropin=present; else dropin=missing; fi
check "hardening drop-in file" "present" "$dropin"

if id "$USER_TO_CHECK" >/dev/null 2>&1; then
  check "user ${USER_TO_CHECK}" "exists" "exists"
  maxdays=$(chage -l "$USER_TO_CHECK" 2>/dev/null | awk -F': ' '/Maximum/ { print $2 }')
  check "password max age (days)" "90" "$maxdays"
else
  check "user ${USER_TO_CHECK}" "exists" "missing"
fi

echo "--------------------------------------------------------------"
echo "Result: ${pass} passed, ${fail} failed"
[[ $fail -eq 0 ]]
