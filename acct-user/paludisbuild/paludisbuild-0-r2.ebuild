# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="Group for paludis package manager"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( "${PN}" kvm jobserver tty video )

ACCT_USER_HOME="/var/lib/paludis/home"
ACCT_USER_HOME_PERMS="750"

acct-user_add_deps
