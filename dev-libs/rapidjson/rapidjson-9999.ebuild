# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="A fast JSON parser/generator for C++ with both SAX/DOM style API"
HOMEPAGE="https://rapidjson.org/"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/miloyip/rapidjson.git"
	EGIT_SUBMODULES=()
	inherit git-r3
else
	SRC_URI="https://github.com/miloyip/rapidjson/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~hppa ~loong ~ppc ~ppc64 ~riscv ~sparc ~x86"
	S="${WORKDIR}/rapidjson-${PV}"
fi

LICENSE="MIT"
SLOT="0"
IUSE="doc examples test valgrind"
RESTRICT="!test? ( test )"

BDEPEND="
	doc? ( app-text/doxygen )
	test? ( dev-cpp/gtest )
	valgrind? ( dev-debug/valgrind )
"

PATCHES=(
	"${FILESDIR}/${P}-system_gtest.patch"
	"${FILESDIR}/${P}-CMP0175.patch"
	"${FILESDIR}/${P}-valgrind-optional.patch"
	"${FILESDIR}/${P}-examples-install-optional.patch"
)

src_prepare() {
	cmake_src_prepare

	sed -i -e 's| -Werror||g' CMakeLists.txt || die

	sed \
		-e "/find_program(CCACHE_FOUND ccache)/s/^/# skipped /g" \
		-i \
			CMakeLists.txt \
			test/perftest/CMakeLists.txt \
			test/unittest/CMakeLists.txt \
		|| die
}

src_configure() {
	local mycmakeargs=(
		-DDOC_INSTALL_DIR="${EPREFIX}/usr/share/doc/${PF}"
		-DLIB_INSTALL_DIR="${EPREFIX}/usr/$(get_libdir)"
		-DRAPIDJSON_BUILD_CXX11="no" # latest gtest requires C++14 or later
		-DRAPIDJSON_BUILD_CXX17="yes"
		-DRAPIDJSON_BUILD_DOC="$(usex doc)"
		-DRAPIDJSON_BUILD_EXAMPLES="$(usex examples)"
		-DRAPIDJSON_BUILD_TESTS="$(usex test)"
		-DRAPIDJSON_BUILD_TESTS_VALGRIND="$(usex test "$(usex valgrind)")"
		-DRAPIDJSON_BUILD_THIRDPARTY_GTEST="no"
		-DRAPIDJSON_ENABLE_INSTRUMENTATION_OPT="no"
		-DRAPIDJSON_HAS_STDSTRING="yes"
		-DRAPIDJSON_USE_MEMBERSMAP="yes"
	)

	cmake_src_configure
}
