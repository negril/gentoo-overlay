# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop virtualx xdg cmake git-r3

DESCRIPTION="Share a mouse and keyboard between computers (fork of Barrier)"
HOMEPAGE="https://github.com/input-leap/input-leap"
EGIT_REPO_URI="https://github.com/input-leap/input-leap.git"
EGIT_SUBMODULES+=( '-ext/*' )

LICENSE="GPL-2"
SLOT="0"
IUSE="X gui +libei qt6 test"
RESTRICT="!test? ( test )"

RDEPEND="
	net-misc/curl
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
	gui? (
		!qt6? (
			dev-qt/qtcore:5
			dev-qt/qtgui:5
			dev-qt/qtnetwork:5
			dev-qt/qtwidgets:5
		)
		qt6? (
				dev-qt/qtbase:6[gui,network,widgets]
		)
		net-dns/avahi[mdnsresponder-compat]
	)
	libei? (
		dev-libs/libei
		x11-libs/libxkbcommon
		dev-libs/glib
		gui? (
			!qt6? (
				dev-libs/libportal[qt5]
			)
			qt6? (
				dev-libs/libportal[qt6]
			)
		)
	)
	dev-libs/openssl:0=
"
DEPEND="
	${RDEPEND}
	dev-cpp/gulrak-filesystem
	X? (
		x11-base/xorg-proto
	)
	test? ( dev-cpp/gtest )
"

DOCS=(
	ChangeLog
	README.md
	doc/${PN}.conf.example{,-advanced,-basic}
)

src_configure() {
	local mycmakeargs=(
		-DINPUTLEAP_BUILD_GUI=$(usex gui)
		-DINPUTLEAP_BUILD_INSTALLER="no"
		-DINPUTLEAP_BUILD_LIBEI="$(usex libei)"
		-DINPUTLEAP_BUILD_TESTS="$(usex test)"
		-DINPUTLEAP_BUILD_X11="$(usex X)"
		# -DINPUTLEAP_REVISION=00000000
		-DINPUTLEAP_USE_EXTERNAL_GTEST="yes"
		-DINPUTLEAP_VERSION_STAGE="gentoo"
	)

	if use gui || use qt6; then
		mycmakeargs+=(
			-DQT_DEFAULT_MAJOR_VERSION="$(usex qt6 6 5)"
		)
	fi

	cmake_src_configure
}

src_test() {
	"${BUILD_DIR}"/bin/unittests || die
	virtx "${BUILD_DIR}"/bin/integtests || die
}

src_install() {
	cmake_src_install
	einstalldocs
	doman doc/${PN}{c,s}.1

	if use gui; then
		doicon -s scalable res/io.github.input_leap.InputLeap.svg
		doicon -s 256 res/${PN}.png
		make_desktop_entry ${PN} InputLeap ${PN} Utility
	fi
}
