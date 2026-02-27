# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Understand your Git history!"
HOMEPAGE="https://murmele.github.io/Gittyup"

LUA_COMPAT=( lua5-4 luajit )

inherit cmake lua-single

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_CLONE_TYPE="shallow"
	EGIT_REPO_URI="https://github.com/Murmele/Gittyup.git"
	EGIT_SUBMODULES=(
		'-*'
		# https://github.com/Murmele/Gittyup/issues/935
		'dep/scintilla/lexilla'
		'dep/scintilla/scintillua'
	)
else
	ZIP_PV="0.3.4"
	SRC_URI="
		https://github.com/Murmele/Gittyup/archive/refs/tags/gittyup_v${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/kuba--/zip/archive/refs/tags/v${ZIP_PV}.tar.gz -> ${P}-zip-${ZIP_PV}.tar.gz
	"
	S="${WORKDIR}/${PN^}-${PN,,}_v${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"

IUSE="debug test"
RESTRICT="!test? ( test )"

REQUIRED_USE="${LUA_REQUIRED_USE}"

RDEPEND="${LUA_DEPS}
	app-text/cmark
	app-text/hunspell
	dev-libs/libgit2:=
	dev-libs/openssl:=
	dev-qt/qtbase:6[concurrent,dbus,gui,network,widgets]
	dev-qt/qttools:6[linguist]
	net-libs/libssh2
"
DEPEND="${RDEPEND}
"

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		EGIT_SUBMODULES+=(
			$(usev test 'test/dep/zip')
		)
		git-r3_src_unpack
	else
		default

		ln -srf "${WORKDIR}/zip-${ZIP_PV}" "${S}/test/dep/zip" || die
	fi
}

src_configure() {
	local mycmakeargs=(
		-DFLATPAK="no"

		-DENABLE_SHA256="no" # requires libgit2 with -DEXPERIMENTAL_SHA256="yes"
		-DENABLE_TESTS="$(usex test)"
		-DENABLE_UPDATE_OVER_GUI="no"

		-DDEBUG_FLATPAK="no"
		-DDEBUG_OUTPUT="$(usex debug)"
		-DDEBUG_OUTPUT_GENERAL="$(usex debug)"
		-DDEBUG_OUTPUT_REFRESH="$(usex debug)"
		-DUSE_SSH="yes"
		-DUSE_SYSTEM_CMARK="yes"
		-DUSE_SYSTEM_GIT="yes"
		-DUSE_SYSTEM_HUNSPELL="yes"
		-DUSE_SYSTEM_LIBGIT2="yes"
		-DUSE_SYSTEM_LIBSSH2="yes"
		-DUSE_SYSTEM_LUA="yes"
		-DUSE_SYSTEM_OPENSSL="yes"
		-DUSE_SYSTEM_QT="yes"

		-DLUA_INCLUDE_DIR="$(lua_get_include_dir)"
	)

	if use test; then
		mycmakeargs+=(
			-DGITTYUP_CI_TESTS="yes"
		)
	fi

	if [[ "${PV}" == *9999* ]]; then
		mycmakeargs+=(
			-DDEV_BUILD:STRING="${EGIT_COMMIT}"
		)
	fi

	cmake_src_configure
}
