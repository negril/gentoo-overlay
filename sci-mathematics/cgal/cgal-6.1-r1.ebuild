# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Modules provided by dev-cpp/eigen
CMAKE_REMOVE_MODULES_LIST=( FindEigen3 )
inherit cmake cuda flag-o-matic multiprocessing

DESCRIPTION="C++ library for geometric algorithms and data structures"
HOMEPAGE="https://www.cgal.org/"
LICENSE="LGPL-3 GPL-3 Boost-1.0"

SRC_URI="
	https://github.com/CGAL/cgal/releases/download/v${PV}/${P^^}.tar.xz
	doc? (
		https://github.com/CGAL/cgal/releases/download/v${PV}/${P^^}-doc_html.tar.xz
	)
"
S="${WORKDIR}/${P^^}"
KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"

SLOT="0/14"
IUSE="demo doc examples test"
RESTRICT="!test? ( test )"

# This seems wrong.
RDEPEND="
	dev-cpp/eigen:=
	dev-libs/boost:=
	dev-libs/gmp:=[cxx]
	dev-libs/mpfr:=
	virtual/zlib:=
	x11-libs/libX11:=
	virtual/glu:=
	virtual/opengl:=
"
DEPEND="${RDEPEND}
	test? (
		net-libs/libssh[server]
		demo? (
			dev-qt/qtbase:6[gui,opengl,widgets]
		)
		examples? (
			media-gfx/openmesh
			dev-qt/qtbase:6[gui,opengl,widgets]
		)
	)
"
BDEPEND="
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${PN}-4.11.1-fix-buildsystem.patch"
	"${FILESDIR}/${PN}-6.1-PR9105.patch"
)

pkg_pretend() {
	if ! use test && { use demos || use examples; }; then
		ewarn "The \"demos\" and \"examples\" useflag require USE=\"test\""
	fi
}

src_prepare() {
	if use doc; then
		rm -r "doc_html" || die
		mv "${WORKDIR}/doc_html" "${S}/" || die
	fi

	cmake_src_prepare
}

src_compile() {
	cmake_src_compile demos
	cmake_src_compile examples
	cmake_src_compile ALL_CGAL_TARGETS
}

src_configure() {
	# Header only
	filter-flags -DNDEBUG*

	local deps=(
		ESBTL
		F2C
		GLPK
		IPE
		ITT
		LASLIB
		LEDA
		libpointmatcher
		LibSSH
		MKL
		MPFI
		# bMPFR
		OpenCV
		OpenGR
		OpenMesh
		OSQP
		RS
		RS3
		SCIP
		TBB
		UMFPACK
		VTK
	)

	local mycmakeargs=(
		-DCMAKE_POLICY_DEFAULT_CMP0167="NEW"
		# 964750
		"$(printf -- "-DCMAKE_DISABLE_FIND_PACKAGE_%s=yes " "${deps[@]}")"

		-DCGAL_INSTALL_LIB_DIR="$(get_libdir)"
		-DCGAL_INSTALL_CMAKE_DIR="$(get_libdir)/cmake/CGAL"

		# https://github.com/CGAL/cgal/wiki/Testing#using-ctest
		-DCGAL_ENABLE_TESTING="$(usex test)"
		-DCGAL_CTEST_DISPLAY_MEM_AND_TIME="yes"
		# exits some tests early
		-DCGAL_TEST_SUITE="yes"
		-DCGAL_TEST_DRAW_FUNCTIONS="yes"
		-DCGAL_WITH_GMPXX="yes"
		# -DCGAL_WITH_benchmark="$(usex test "$(usex benchmark)")" # wired up but not present
		-DCGAL_WITH_demos="$(usex test "$(usex demo)")"
		-DCGAL_WITH_examples="$(usex test "$(usex examples)")"
	)

	# Optionally depends on sci-lib/vtk, which looks up a cuda compiler iff build with USE=cuda.
	# We therefore need to set the correct CUDAHOSTCXX and setup the sandbox.
	if use test && { use demo || use examples; }; then
		if has_version "sci-libs/vtk[cuda]" ; then
			cuda_add_sandbox -w
			addpredict "/dev/char/"
		fi
	fi

	cmake_src_configure
}

src_test() {
	# tests have split compilation & execution stages that do not depend on each other, but break when run out of order
# 	local -x CTEST_JOBS="1"
# 	einfo "using CTEST_JOBS=${CTEST_JOBS}"
#
# 	# We pass CMAKE_BUILD_PARALLEL_LEVEL to run compilation tests in parallel
# 	local -x CMAKE_BUILD_PARALLEL_LEVEL="17" # $(get_makeopts_jobs 999)"
# 	einfo "using CMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL}"
#
# 	# We pass CTEST_PARALLEL_LEVEL to run execution tests in parallel
# 	local -x CTEST_PARALLEL_LEVEL="17" # $(get_makeopts_jobs 999)"
# 	einfo "using CTEST_PARALLEL_LEVEL=${CTEST_PARALLEL_LEVEL}"

	local -x QT_QPA_PLATFORM="offscreen"
	cmake_src_test
}

src_install() {
	if use doc; then
		local HTML_DOCS=(
			"doc_html/."
		)
	fi

	cmake_src_install

	if use demo; then
		dodoc -r demo
	fi

	if use examples; then
		dodoc -r examples
	fi
}
