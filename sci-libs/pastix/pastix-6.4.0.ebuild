# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit bash-completion-r1 cmake cuda fortran-2 python-single-r1 toolchain-funcs

DESCRIPTION="Parallel solver for very large sparse linear systems"
HOMEPAGE="https://solverstack.gitlabpages.inria.fr/pastix/ https://gitlab.inria.fr/solverstack/pastix"
SRC_URI="https://files.inria.fr/pastix/releases/v$(ver_cut 1)/${P}.tar.gz"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~loong ~ppc ~ppc64 ~riscv ~sparc ~x86 ~amd64-linux ~x86-linux"
IUSE="cuda examples +fortran int64 metis mpi +python +scotch starpu test"

RESTRICT="!test? ( test )"

# REQUIRED_USE explanation:
# 1. Not a typo, Python is needed at build time regardless of whether
#    the bindings are to be installed or not
# 2. While not enforced by upstream build scripts, having no ordering at all
#    results in rather spectacular test and runtime failures.
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	|| ( metis scotch )
"

RDEPEND="
	sys-apps/hwloc:0=
	virtual/blas
	virtual/cblas
	virtual/lapack
	virtual/lapacke
	cuda? ( dev-util/nvidia-cuda-toolkit )
	metis? ( sci-libs/metis[int64(+)=] )
	mpi? (
		virtual/mpi[fortran]
		metis? ( sci-libs/parmetis )
	)
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/numpy[${PYTHON_USEDEP}]
			dev-python/scipy[${PYTHON_USEDEP}]
		')
	)
	scotch? ( >=sci-libs/scotch-6.1.0-r1:0=[int64=,mpi?] )
	starpu? ( >=dev-libs/starpu-1.3.0:0= )
"
DEPEND="${RDEPEND}"
BDEPEND="
	${PYTHON_DEPS}
	virtual/pkgconfig
	test? ( ${RDEPEND} )
"

PATCHES=(
	# "${FILESDIR}/${PN}-6.4.0-cmake-installdirs.patch"
	# "${FILESDIR}/${PN}-6.4.0-cmake-examples-optional.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake-python-optional.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake-spm-project.patch"
	# "${FILESDIR}/${PN}-6.4.0-cmake-min-version.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake-cuda.patch"
	"${FILESDIR}/${PN}-6.4.0-scipy.patch"
)

cuda_check_compiler() {
	[[ -z "$1" ]] && die "no compiler specified"
	local compiler="$1"
	local package="sys-devel/${compiler}"
	local version="${package}"
	local CUDAHOSTCXX_test
	while
		CUDAHOSTCXX="${CUDAHOSTCXX_test}"
		version=$(best_version "${version}")
		if [[ -z "${version}" ]]; then
			if [[ -z "${CUDAHOSTCXX}" ]]; then
				die "could not find supported version of ${package}"
			fi
			break
		fi
		CUDAHOSTCXX_test="$(
			dirname "$(
				realpath "$(
					which "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
				)"
			)"
		)"
		version="<${version}"
	do ! echo "int main(){}" | nvcc "-ccbin=${CUDAHOSTCXX_test}" - -x cu &>/dev/null; done
}

pkg_setup() {
	python-single-r1_pkg_setup
}

src_prepare () {
	sed -r \
		-e 's:\\([()\^]):\\\\\1:g' \
		-i \
			cmake_modules/morse_cmake/modules/precision_generator/subs.py \
			spm/cmake_modules/morse_cmake/modules/precision_generator/subs.py \
		|| die

	cmake_src_prepare

	sed \
		-e "s:DESTINATION bin:DESTINATION $(get_bashcompdir):" \
		-i CMakeLists.txt \
		|| die

	local PYTHON_SITE_DIR
	PYTHON_SITE_DIR=$(python_get_sitedir)

	sed \
		-e "s#[^:]*python\$#${PYTHON_SITE_DIR}#g" \
		-i spm/tools/spm_env.sh.in \
		|| die

	sed \
		-e "s:DESTINATION \${CMAKE_INSTALL_LIBDIR}/python:DESTINATION ${PYTHON_SITE_DIR}:g" \
		-i \
			wrappers/python/CMakeLists.txt \
			spm/wrappers/python/CMakeLists.txt \
		|| die
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS="yes"
		-DINSTALL_EXAMPLES="$(usex examples)"
		-DPASTIX_INT64="$(usex int64)"
		-DPASTIX_ORDERING_METIS="$(usex metis)"
		-DPASTIX_ORDERING_SCOTCH="$(usex scotch)"
		-DPASTIX_WITH_CUDA="$(usex cuda)"
		-DPASTIX_WITH_FORTRAN="$(usex fortran)"
		-DPASTIX_WITH_MPI="$(usex mpi)"
		-DPASTIX_WITH_PYTHON="$(usex python)"
		-DPASTIX_WITH_STARPU="$(usex starpu)"
		-DSPM_INT64="$(usex int64)"
		-DSPM_WITH_FORTRAN="$(usex fortran)"
		-DSPM_WITH_MPI="$(usex mpi)"
		-DSPM_WITH_SCOTCH="$(usex scotch)"
	)

	if use cuda; then
		cuda_add_sandbox -w
		tc-is-gcc && cuda_check_compiler "gcc"
		tc-is-clang && cuda_check_compiler "clang"
		[[ -z "${CUDAARCHS}" ]] && einfo "trying to determine host CUDAARCHS"
		: "${CUDAARCHS:=$(__nvcc_device_query)}"
		einfo "building for CUDAARCHS = ${CUDAARCHS}"

		mycmakeargs+=(
			-DCUDA_NVCC_FLAGS="-ccbin ${CUDAHOSTCXX} -arch sm_${CUDAARCHS} -DCUDA_SM_VERSION=${CUDAARCHS}"
		)

	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install
	use python && python_optimize
}

src_test() {
	use cuda && cuda_add_sandbox -w

	cmake_src_test
}
