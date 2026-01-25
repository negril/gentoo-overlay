# Copyright 2020-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic qmake-utils

DESCRIPTION="OpenRGB plugin for syncing your Motherboard Fans with hardware measures (CPU, GPU, etc...)"
HOMEPAGE="https://gitlab.com/OpenRGBDevelopers/OpenRGBFanSyncPlugin"
LICENSE="GPL-2"

MY_PN="OpenRGBFanSyncPlugin"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.com/OpenRGBDevelopers/${MY_PN}.git"
	EGIT_SUBMODULES=( '-*' )
else
	MY_PV=$(ver_rs 2 "")
	SRC_URI="
		https://gitlab.com/OpenRGBDevelopers/${MY_PN}/-/archive/release_candidate_${MY_PV}/${MY_PN}-release_candidate_${MY_PV}.tar.bz2
	"
	S="${WORKDIR}/${MY_PN}-release_candidate_${MY_PV}"
	KEYWORDS="~amd64"
fi

SLOT="0"

RDEPEND="
	>=app-misc/openrgb-0.9_p20250802:=
	dev-libs/hidapi
	dev-qt/qtbase:6[gui,opengl,widgets,-gles2-only]
	dev-qt/qt5compat:6
	media-libs/libglvnd
	media-libs/openal
	media-video/pipewire:=
	gnome-base/libgtop
"
DEPEND="
	${RDEPEND}
	dev-cpp/nlohmann_json
"

PATCHES=(
	"${FILESDIR}/${PN}-1.0_rc2-drop-git.patch"
	"${FILESDIR}/${PN}-1.0_rc2-system-openrgb.patch"
)

src_prepare() {
	default

	filter-lto # Bug 927749

	rm -r OpenRGB || die
	ln -s "${ESYSROOT}/usr/include/OpenRGB" . || die
	sed -e '/^GIT_/d' -i ./*.pro || die

	# Because of -Wl,--export-dynamic in app-misc/openrgb, this resources.qrc
	# conflicts with the openrgb's one. So rename it.
	sed -e 's/ resources.qrc/ resources_effects_plugin.qrc/' -i ./*.pro || die "sed qmake"
	mv --no-clobber resources.qrc resources_effects_plugin.qrc || die mv
}

src_configure() {
	eqmake6 \
		INCLUDEPATH+="${ESYSROOT}/usr/include/nlohmann" \
		INCLUDEPATH+="${ESYSROOT}/usr/include/OpenRGB/hidapi_wrapper" \
		CONFIG+=link_pkgconfig \
		PKGCONFIG+=hidapi-hidraw
}

src_install() {
	exeinto /usr/$(get_libdir)/openrgb/plugins
	doexe "lib${MY_PN}.so"
}
