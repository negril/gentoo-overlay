# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake-multilib

DESCRIPTION="A portable, open-source, coherent noise-generating library for C++"
HOMEPAGE="http://libnoise.sourceforge.net"

SRC_URI="
	https://prdownloads.sourceforge.net/${PN}/${PN}src-${PV}.zip
"
S="${WORKDIR}/${PN%%-${PV}}"
KEYWORDS="~amd64"

LICENSE="LGPL-2"
SLOT="0"

BDEPEND="
	app-arch/unzip
"

src_prepare() {
	cp "${FILESDIR}/CMakeLists.txt" "${S}/CMakeLists.txt" || die

	cmake_src_prepare
}
