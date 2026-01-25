# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="Run a command in a virtual wayland server environment"
HOMEPAGE="https://gitlab.freedesktop.org/ofourdan/xwayland-run"

if [[ ${PV} == *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.freedesktop.org/ofourdan/${PN}.git"
else
	SRC_URI="
		https://gitlab.freedesktop.org/ofourdan/${PN}/-/archive/${PV}/${P}.tar.bz2
	"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="GPL-2+"
SLOT="0"

# src_configure() {
#         local emesonargs=(
#         )
#         meson_src_configure
# }
