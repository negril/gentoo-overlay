# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

inherit vdr-plugin-2 git-r3

EGIT_REPO_URI="https://github.com/mdre77/vdr-plugin-vnsiserver.git"

DESCRIPTION="VDR plugin to handle Kodi clients"
HOMEPAGE="https://github.com/mdre77/vdr-plugin-vnsiserver"
SRC_URI=""

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND="media-video/vdr"
RDEPEND="${DEPEND}"

src_prepare() {
	vdr-plugin-2_src_prepare

	fix_vdr_libsi_include demuxer.c
	fix_vdr_libsi_include videoinput.c
}

src_install() {
	vdr-plugin-2_src_install

	insinto /etc/vdr/plugins/vnsiserver
	doins vnsiserver/allowed_hosts.conf
	diropts -gvdr -ovdr
}
