# Copyright 2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="Group for paludis package manager"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( ${PN} tty )

ACCT_USER_HOME="/var/tmp/paludis"
ACCT_USER_HOME_PERMS="760"

acct-user_add_deps
