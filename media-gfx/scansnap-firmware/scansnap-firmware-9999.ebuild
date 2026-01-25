# Copyright 2020-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

if [[ ${PV} == "9999" ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/stevleibelt/${PN}.git"
else
	SRC_URI="https://github.com/stevleibelt/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="Firmware for Fujitsu Scansnap scanners"
HOMEPAGE="https://github.com/stevleibelt/scansnap-firmware"

LICENSE="public-domain"
SLOT="0"

src_install() {
	insinto /usr/share/sane/epjitsu/
	doins ./*
}
