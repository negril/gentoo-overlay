# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake-multilib

DESCRIPTION="Lossless, high performance data compression library"
HOMEPAGE="https://github.com/richgel999/miniz"
SRC_URI="https://github.com/richgel999/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/${PV}"
KEYWORDS="~amd64 ~arm64 ~x86"

DOCS=( ChangeLog.md readme.md )

PATCHES=( "${FILESDIR}/${PN}-3.0.2-cmake4.patch" ) # bug 951684
