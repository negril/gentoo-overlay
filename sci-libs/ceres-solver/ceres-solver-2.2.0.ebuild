# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
DOCS_BUILDER="sphinx"
DOCS_DEPEND="dev-python/sphinx-rtd-theme"
DOCS_DIR="docs/source"
inherit cmake-multilib cuda flag-o-matic python-any-r1 docs

DESCRIPTION="Nonlinear least-squares minimizer"
HOMEPAGE="http://ceres-solver.org/"
SRC_URI="http://ceres-solver.org/${P}.tar.gz"

LICENSE="sparse? ( BSD ) !sparse? ( LGPL-2.1 )"
SLOT="0/1"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="examples cuda gflags lapack +schur sparse test"

REQUIRED_USE="test? ( gflags ) sparse? ( lapack ) abi_x86_32? ( !sparse !lapack )"
RESTRICT="!test? ( test )"

BDEPEND="${PYTHON_DEPS}
	>=dev-cpp/eigen-3.3.4:3
	lapack? ( virtual/pkgconfig )
	doc? ( <dev-libs/mathjax-3 )
"
RDEPEND="
	dev-cpp/glog[gflags?,${MULTILIB_USEDEP}]
	lapack? ( virtual/lapack )
	sparse? (
		sci-libs/amd
		sci-libs/camd
		sci-libs/ccolamd
		sci-libs/cholmod[metis(+)]
		sci-libs/colamd
		sci-libs/spqr
	)
"
DEPEND="${RDEPEND}"

DOCS=( README.md VERSION )

PATCHES=(
	"${FILESDIR}/${PN}-2.0.0-system-mathjax.patch"
)

# cuda_get_cuda_compiler() {
# 	local compiler
# 	tc-is-gcc && compiler="gcc"
# 	tc-is-clang && compiler="clang"
# 	[[ -z "$compiler" ]] && die "no compiler specified"
#
# 	local package="sys-devel/${compiler}"
# 	local version="${package}"
# 	local CUDAHOSTCXX_test
# 	while
# 		local CUDAHOSTCXX="${CUDAHOSTCXX_test}"
# 		version=$(best_version "${version}")
# 		if [[ -z "${version}" ]]; then
# 			if [[ -z "${CUDAHOSTCXX}" ]]; then
# 				die "could not find supported version of ${package}"
# 			fi
# 			break
# 		fi
# 		CUDAHOSTCXX_test="$(
# 			dirname "$(
# 				realpath "$(
# 					which "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
# 				)"
# 			)"
# 		)"
# 		version="<${version}"
# 	do ! echo "int main(){}" | nvcc "-ccbin ${CUDAHOSTCXX_test}" - -x cu &>/dev/null; done
#
# 	echo "${CUDAHOSTCXX}"
# }
#
# cuda_get_host_native_arch() {
# 	: "${CUDAARCHS:=$(__nvcc_device_query)}"
# 	echo "${CUDAARCHS}"
# }
#
# pkg_pretend() {
# 	if use cuda && [[ -z "${CUDA_GENERATION}" ]] && [[ -z "${CUDA_ARCH_BIN}" ]]; then # TODO CUDAARCHS
# 		einfo "The target CUDA architecture can be set via one of:"
# 		einfo "  - CUDA_GENERATION set to one of Maxwell, Pascal, Volta, Turing, Ampere, Lovelace, Hopper, Auto"
# 		einfo "  - CUDA_ARCH_BIN, (and optionally CUDA_ARCH_PTX) in the form of x.y tuples."
# 		einfo "      You can specify multiple tuple separated by \";\"."
# 		einfo ""
# 		einfo "The CUDA architecture tuple for your device can be found at https://developer.nvidia.com/cuda-gpus."
# 	fi
#
# 	if [[ ${MERGE_TYPE} == "buildonly" ]] && [[ -n "${CUDA_GENERATION}" || -n "${CUDA_ARCH_BIN}" ]]; then
# 		local info_message="When building a binary package it's recommended to unset CUDA_GENERATION and CUDA_ARCH_BIN"
# 		einfo "$info_message so all available architectures are build."
# 	fi
# }

src_prepare() {

	cmake_src_prepare

	filter-lto

	# search paths work for prefix
	sed -e "s:/usr:${EPREFIX}/usr:g" \
		-i cmake/*.cmake || die

	# remove Werror
	sed -e 's/-Werror=(all|extra)//g' \
		-i CMakeLists.txt || die
}

src_configure() {
	# CUSTOM_BLAS=OFF EIGENSPARSE=OFF MINIGLOG=OFF
	local mycmakeargs=(
		-DBUILD_BENCHMARKS=OFF
		-DBUILD_DOCUMENTATION="$(usex doc)"
		-DBUILD_EXAMPLES="$(usex examples)"
		-DBUILD_SHARED_LIBS="yes"
		-DBUILD_TESTING="$(usex test)"

		-DEIGENMETIS="yes"
		-DEIGENSPARSE="yes"
		-DGFLAGS="$(usex gflags)"
		-DLAPACK="$(usex lapack)"
		-DMINIGLOG="no"
		-DSUITESPARSE="$(usex sparse)"
		-DCUSTOM_BLAS="yes"
		-DEigen3_DIR="/usr/$(get_libdir)/cmake/eigen3"

		-DSCHUR_SPECIALIZATIONS="$(usex schur)"
		-DUSE_CUDA="$(usex cuda)"

	)

	if use cuda; then
		# cuda_add_sandbox -w
		CUDAHOSTCXX="$(cuda_gccdir)"
		CUDAARCHS="all"
		export CUDAHOSTCXX
		export CUDAARCHS
	fi

	use sparse || mycmakeargs+=( -DEIGENSPARSE=ON )

	cmake-multilib_src_configure
}

src_test() {
	use cuda && cuda_add_sandbox -w
	cmake_src_test
}

src_install() {
	cmake-multilib_src_install

	if use examples; then
		docompress -x /usr/share/doc/${PF}/examples
		dodoc -r examples data
	fi
}
