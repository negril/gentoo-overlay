# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

VIRTUALX_REQUIRED="manual"
inherit cmake edo virtualx xdg
inherit desktop

if [[ ${PV} == *9999* ]]; then
	EGIT_REPO_URI="https://github.com/input-leap/input-leap.git"
	inherit git-r3
	EGIT_SUBMODULES+=( '-ext/*' )
else
	SRC_URI="https://github.com/input-leap/input-leap/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="Share a mouse and keyboard between computers (fork of Barrier)"
HOMEPAGE="https://github.com/input-leap/input-leap"

LICENSE="GPL-2"
SLOT="0"
IUSE="+X gui test +wayland"
REQUIRED_USE="|| ( wayland X )"
RESTRICT="!test? ( test )"

RDEPEND="
	dev-libs/openssl:0=
	gui? (
		dev-qt/qtbase:6[gui,network,widgets,X?]
		net-dns/avahi[mdnsresponder-compat]
	)
	wayland? (
		dev-libs/glib:2
		dev-libs/libei
		x11-libs/libxkbcommon
		gui? (
			dev-libs/libportal:=[qt6(+)]
		)
	)
	X? (
		x11-libs/libICE
		x11-libs/libSM
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXinerama
		x11-libs/libXrandr
		x11-libs/libXtst
	)
"
DEPEND="
	${RDEPEND}
	dev-cpp/gulrak-filesystem
	X? (
		x11-base/xorg-proto
	)
	test? ( dev-cpp/gtest )
"
BDEPEND="
	virtual/pkgconfig
	gui? ( dev-qt/qttools:6[linguist] )
	test? ( X? ( ${VIRTUALX_DEPEND} ) )
"

DOCS=(
	ChangeLog
	README.md
	doc/${PN}.conf.example{,-advanced,-basic}
)

src_prepare() {
	# respect CXXFLAGS
	sed -i '/CMAKE_POSITION_INDEPENDENT_CODE/d' CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	local REV="${EGIT_VERSION:-00000000}"
	local mycmakeargs=(
		-DINPUTLEAP_BUILD_GUI=$(usex gui)
		-DINPUTLEAP_BUILD_LIBEI=$(usex wayland)
		-DINPUTLEAP_BUILD_TESTS=$(usex test)
		-DINPUTLEAP_BUILD_X11=$(usex X)
		-DINPUTLEAP_REVISION="${REV:0:8}"
		-DINPUTLEAP_USE_EXTERNAL_GTEST=ON
		-DINPUTLEAP_VERSION_STAGE="gentoo"
	)
	cmake_src_configure
}

src_test() {
	edo "${BUILD_DIR}/bin/unittests"

	if use X; then
		edo virtx "${BUILD_DIR}/bin/integtests"
	else
		edo "${BUILD_DIR}/bin/integtests"
	fi
}

src_install() {
	cmake_src_install
	einstalldocs

	doman "doc/${PN}"{c,s}.1

	if use gui; then
		doicon -s scalable "res/io.github.input_leap.input-leap.svg"
		doicon -s 256 "res/${PN}.png"
		make_desktop_entry "${PN}" "InputLeap" "${PN}" "Utility"
	fi
}
