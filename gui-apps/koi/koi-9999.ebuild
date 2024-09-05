# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Theme scheduling for the KDE Plasma Desktop"
HOMEPAGE="https://github.com/baduhai/Koi"

if [[ "${PV}" == 9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/baduhai/Koi.git"
	MY_PN="${PN}"
else
	SRC_URI="https://github.com/baduhai/Koi/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
	MY_PN="Koi"
	KEYWORDS="~amd64 ~arm64"
fi
S="${WORKDIR}/${MY_PN}-${PV}/src"
unset MY_PN

LICENSE="LGPL-3"
SLOT="0"

DEPEND="
	kde-frameworks/kconfig:6
	kde-frameworks/kcoreaddons:6
	kde-frameworks/kwidgetsaddons:6
	media-libs/libglvnd[X(+)]
	x11-libs/libxkbcommon
	dev-qt/qtbase:6[dbus,gui,network]
	dev-qt/qtbase:6[widgets]
	dev-qt/qtbase:6[xml]
"
RDEPEND="${DEPEND}"
