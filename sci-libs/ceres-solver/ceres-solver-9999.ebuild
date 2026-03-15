# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# TODO
# - multilib? Why?

PYTHON_COMPAT=( python3_{12..13} )
DOCS_BUILDER="sphinx"
DOCS_DEPEND="dev-python/sphinx-rtd-theme"
DOCS_DIR="docs/source"
inherit cmake-multilib cuda python-any-r1 docs

DESCRIPTION="Nonlinear least-squares minimizer"
HOMEPAGE="http://ceres-solver.org/ https://github.com/ceres-solver/ceres-solver"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_SUBMODULES=()
	EGIT_REPO_URI="https://github.com/ceres-solver/ceres-solver.git"
else
	SRC_URI="
		https://github.com/ceres-solver/ceres-solver/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
		http://ceres-solver.org/${P}.tar.gz
	"
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="sparse? ( BSD ) !sparse? ( LGPL-2.1 )"
# SONAME
SLOT="0/4"
# TODO openmp? tbb?
IUSE="+eigen examples cuda cudss lapack metis +schur sparse test"

REQUIRED_USE="
	|| ( cudss eigen sparse )
	sparse? (
		lapack
	)
	abi_x86_32? (
		!sparse
		!lapack
	)
"
# 	test? ( gflags )
# "

RESTRICT="!test? ( test )"

BDEPEND="${PYTHON_DEPS}
	lapack? (
		virtual/pkgconfig
	)
	doc? (
		<dev-libs/mathjax-3
	)
"
RDEPEND="
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
	)
	cudss? (
		dev-libs/cudss:=
	)
	eigen? (
		>=dev-cpp/eigen-3.3.4:=
		metis? (
			sci-libs/metis
		)
	)
	sparse? (
		sci-libs/amd
		sci-libs/camd
		sci-libs/ccolamd
		sci-libs/cholmod[metis(+)]
		sci-libs/colamd
		sci-libs/spqr
	)
	lapack? (
		virtual/lapack
	)
"

DEPEND="${RDEPEND}"

DOCS=( README.md CITATION.cff )

PATCHES=(
	"${FILESDIR}/${PN}-2.0.0-system-mathjax.patch"
	"${FILESDIR}/${PN}-9999-CUDAARCHS.patch"
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

	# search paths work for prefix
	sed -e "s:/usr:${EPREFIX}/usr:g" \
		-i cmake/*.cmake || die

	# Tries to find ../../data from tests. Which doesn't work with out of source build.
	# Create symlink to not have to touch the source code
	ln -rs "${S}/data" "${WORKDIR}/data" || die

	# remove Werror
	sed \
		-e 's/-Werror=(all|extra)//g' \
		-i CMakeLists.txt || die
}

src_configure() {
	# CUSTOM_BLAS=OFF EIGENSPARSE=OFF MINIGLOG=OFF
	local mycmakeargs=(
		-DBUILD_BENCHMARKS="no"
		-DBUILD_DOCUMENTATION="$(usex doc)"
		-DBUILD_EXAMPLES="$(usex examples)"
		-DBUILD_SHARED_LIBS="yes"
		-DBUILD_TESTING="$(usex test)"

		-DUSE_CUDA="$(usex cuda)" # USE_CUDA=static

		# TODO sort out the eigen/sparse interaction. Are they exclusive?
		-DEIGENMETIS="$(usex eigen "$(usex metis)")"
		-DEIGENSPARSE="$(usex eigen)"
		-DSUITESPARSE="$(usex sparse)"
		-Dcudss_DIR="$(usex cuda "$(usex cudss "${CUDNN_PATH:-${ESYSROOT}/opt/cuda}/$(get_libdir)/cmake/cudss" NOTFOUND)")"
		# --debug-find-pkg="cudss"
		-DCUSTOM_BLAS="yes"

		-DLAPACK="$(usex lapack)"

		-DSCHUR_SPECIALIZATIONS="$(usex schur)"
	)

	if use cuda ; then
		cuda_add_sandbox
		addpredict "/dev/char/"

		: "${CUDAHOSTCXX:=$(cuda_gccdir)}"
		: "${CUDAARCHS:=all}"
		export CUDAHOSTCXX
		export CUDAARCHS
	fi

	if use eigen ; then
		mycmakeargs+=(
			-DEigen3_DIR="${ESYSROOT}/usr/$(get_libdir)/cmake/eigen3"
		)
	fi

	cmake-multilib_src_configure
}

src_test() {
	if use cuda ; then
		cuda_add_sandbox -w
	fi

	cmake-multilib_src_test
}

src_install() {
	cmake-multilib_src_install

	if use examples ; then
		docompress -x "/usr/share/doc/${PF}/examples"
		dodoc -r examples data
	fi
}
