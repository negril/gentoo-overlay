# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit branding cmake flag-o-matic

DESCRIPTION="Per-Face Texture Mapping for Production Rendering"
HOMEPAGE="https://ptex.us/"

if [[ ${PV} == *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/wdas/ptex.git"
else
	SRC_URI="
		https://github.com/wdas/ptex/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64 ~arm ~arm64 ~riscv ~x86"
fi

LICENSE="BSD"
# SONAME
SLOT="0/$(ver_cut 1-2)"
IUSE="doc test"

RESTRICT="!test? ( test )"

RDEPEND="
	app-arch/libdeflate
"

DEPEND="${RDEPEND}"

BDEPEND="
	doc? (
		app-text/doxygen
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-2.5.1-fix-pkgconfig.patch"
)

src_prepare() {
	# https://github.com/wdas/ptex/issues/41
	cat <<-EOF > version || die
	v${PV}
	EOF

	cmake_src_prepare
}

src_configure() {
	# replace-flags -O3 -O2
	append-cxxflags -fno-tree-dce -fno-tree-dse

	local mycmakeargs=(
		-DCMAKE_INSTALL_DOCDIR="share/doc/${PF}/html"

		# fix pc file
		-Dpc_req_public="libdeflate"
		-DCMAKE_PROJECT_DESCRIPTION="${DESCRIPTION}"
		-DCMAKE_PROJECT_HOMEPAGE_URL="${HOMEPAGE}"

		-DPTEX_BUILD_DOCS="$(usex doc)"
		-DPTEX_BUILD_SHARED_LIBS="yes"
		-DPTEX_BUILD_STATIC_LIBS="no"
	)

	if [[ ${PV} != *9999* ]] ; then
		# tries to use git otherwise
		mycmakeargs+=(
			-DPTEX_VER="${PV}"
			-DPTEX_SHA="${BRANDING_OS_NAME}"
		)
	fi

	cmake_src_configure
}

src_test() {
	# local CMAKE_SKIP_TESTS=(
	# 	# Program received signal SIGSEGV, Segmentation fault.
	# 	# 0x00007ffff7f4ab26 in Ptex::v2_5::PtexReader::getData(int, void*, int, Ptex::v2_5::Res) ()
	# 	from /var/tmp/paludis/media-libs-ptex-2.5.1/work/ptex-2.5.1_build/src/ptex/libPtex.so.2.5
	# 	"^rtest$"
	# )
	cmake_src_test --extra-verbose

	# cd "${BUILD_DIR}/src/tests" || die

	# local test tests=(
	# 	wtest
	# 	halftest
	# 	rtest
	# 	ftest
	# )

	# for test in "${tests[@]}"; do
	# 	sh &> "./${test}_valgrind.log" <<-_EOF_
	# 		echo valgrind --leak-check=full --trace-children=yes --track-origins=yes "./${test}"
	# 		valgrind --leak-check=full --trace-children=yes --track-origins=yes "./${test}"
	# 	_EOF_
	# done

	# wgetpaste -s pgz ./*_valgrind.log

	# die
}
