# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake toolchain-funcs

DESCRIPTION="Automatic differentiation system for C/C++"
HOMEPAGE="https://projects.coin-or.org/ADOL-C/ https://github.com/coin-or/ADOL-C"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/coin-or/ADOL-C.git"
else
	SRC_URI="
		https://github.com/coin-or/ADOL-C/archive/releases/${PV}.tar.gz -> ${P}.tar.gz
	"
	S="${WORKDIR}/ADOL-C-releases-${PV}"
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ppc ~ppc64 ~riscv ~x86"
fi

LICENSE="|| ( EPL-1.0 GPL-2 )"
SLOT="0/$(ver_cut 1)"

IUSE="+boost doc mpi openmp sparse test"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	sparse? ( openmp )
"

RDEPEND="
	mpi? (
		sys-cluster/medipack:=
	)
	sparse? (
		>sci-libs/colpack-1.0.10[openmp?]
	)
"
DEPEND="${RDEPEND}
	boost? (
		dev-libs/boost:=
	)
"
BDEPEND="
	doc? (
		app-text/doxygen
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-9999-boost-1.90.patch"
)

pkg_pretend() {
	if [[ ${MERGE_TYPE} != binary ]] && use openmp; then
		tc-check-openmp
	fi
}

pkg_setup() {
	if [[ ${MERGE_TYPE} != binary ]] && use openmp; then
		tc-check-openmp
	fi
}

src_prepare() {
	cmake_src_prepare

	sed -e 's/...<1.2//' -i CMakeLists.txt || die
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_INTERFACE="yes" # build the C interface library and headers for foreign language bindings
		-DBUILD_TESTS="$(usex test)"
		-DBUILD_TESTS_WITH_COV="$(usex test no)"

		$(cmake_use_find_package doc Doxygen)
		$(cmake_use_find_package openmp OpenMP)

		# -DENABLE_ACTIVITY_TRACKING="no" # Activity tracking to reduce trace size but increased tracing time.
		# -DENABLE_ADDEXA="$(usex examples)" # build additional examples
		# -DENABLE_ADVANCED_BRANCHING="no" # Advanced branching operations to reduce retaping.
		-DENABLE_BOOST_POOL="$(usex boost)" # Enable the use of boost pool"
		# -DENABLE_DOCEXA="$(usex examples)" # build documented examples
		# -DENABLE_HARDDEBUG="no" # Hard debug mode.
		-DENABLE_MEDIPACK="$(usex mpi)" # MeDiPack: MPI wrapper for Algorithmic Differentiation tools.
		# -DENABLE_PAREXA="$(usex examples)" # build parallel example (OpenMP required!)
		-DENABLE_SPARSE="$(usex sparse)" # build sparse drivers (colpack required!)
		# -DENABLE_STDCZERO="yes" # Do not initialize the values to zero.
		# -DENABLE_TAPEDOC_VALUES="no" # should the tape_doc routine compute the values as it interprets and prints the tape contents
		# -DENABLE_TRACELESS_REFCOUNTING="no" # Reference counting for tapeless numbers.
	)

	if use sparse; then
		mycmakeargs+=(
			-DColPack_DIR="${ESYSROOT}"/usr
		)
	fi

	cmake_src_configure
}
