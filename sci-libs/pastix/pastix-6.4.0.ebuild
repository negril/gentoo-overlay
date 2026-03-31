# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )

# add gdb symbols in debug and relwithdebinfo
CMAKE_BUILD_TYPE="Release"

inherit bash-completion-r1 cmake cuda fortran-2 python-single-r1 toolchain-funcs

DESCRIPTION="Parallel solver for very large sparse linear systems"
HOMEPAGE="https://solverstack.gitlabpages.inria.fr/pastix/ https://gitlab.inria.fr/solverstack/pastix"
LICENSE="LGPL-3"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.inria.fr/solverstack/${PN}.git"
else
	SRC_URI="https://files.inria.fr/pastix/releases/v$(ver_cut 1)/${P}.tar.gz"
	SLOT="0"
	KEYWORDS="~amd64 ~arm ~arm64 ~loong ~ppc ~ppc64 ~riscv ~sparc ~x86"
fi

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

# sci-libs/mkl creates incomplete include paths
RDEPEND="
	!sci-libs/mkl
	sys-apps/hwloc:0=
	virtual/blas
	virtual/cblas
	virtual/lapack
	virtual/lapacke
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
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
	test? ( ${RDEPEND}
		python? (
			${PYTHON_DEPS}
			$(python_gen_cond_dep '
				dev-python/mpi4py[${PYTHON_USEDEP}]
			')
		)
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-6.4.0-cmake-python-optional.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake-spm-project.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake-cuda.patch"
	"${FILESDIR}/${PN}-6.4.0-scipy.patch"
	"${FILESDIR}/${PN}-6.4.0-GNUInstallDirs.patch"
	"${FILESDIR}/${PN}-6.4.0-cmake4.patch"
	"${FILESDIR}/${PN}-6.4.0-scipy-1.13.patch"
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

cuda_get_host_compiler() {
	if [[ -v NVCC_CCBIN ]]; then
		echo "${NVCC_CCBIN}"
		return
	fi

	if [[ -v CUDAHOSTCXX ]]; then
		echo "${CUDAHOSTCXX}"
		return
	fi

	einfo "Trying to find working CUDA host compiler"

	if ! tc-is-gcc && ! tc-is-clang; then
		die "$(tc-get-compiler-type) compiler is not supported"
	fi

	# TODO logic flaw
	# we don't define NVCC_CCBIN as local here as it would override the env var, but we return if it set
	# we then set NVCC_CCBIN to tc-getCXX, and later export it on success

	# compiler with CHOST prefix
	# x86_64-pc-linux-gnu-g++
	local compiler

	# gcc or clang
	local compiler_type

	# major version of the current compiler. 15
	local compiler_version

	# cat/pkg of the compiler
	# sys-devel/gcc, llvm-core/clang
	local package

	# QPN of the package we are checking
	# sys-devel/gcc, <sys-devel/gcc-15
	local package_version

	# system compiler e.g. tc-getCXX plus version
	# used to skip rechecking, as we check NVCC_CCBIN first
	# x86_64-pc-linux-gnu-g++-15
	local NVCC_CCBIN_default

	compiler_type="$(tc-get-compiler-type)"
	compiler_version="$("${compiler_type}-major-version")"

	# try the default compiler first
	NVCC_CCBIN="$(tc-getCXX)"
	NVCC_CCBIN_default="${NVCC_CCBIN}-${compiler_version}"

	compiler="${NVCC_CCBIN/%-${compiler_version}}"

# 	eqawarn "asdf compiler: $compiler"
# 	eqawarn "asdf compiler_type: $compiler_type"
# 	eqawarn "asdf compiler_version: $compiler_version"
#
# 	eqawarn "asdf package: $package"
#
# 	eqawarn "asdf NVCC_CCBIN: $NVCC_CCBIN"
# 	eqawarn "asdf NVCC_CCBIN_default: $NVCC_CCBIN_default"

	# store the package so we can re-use it later
	if tc-is-gcc; then
		package="sys-devel/${compiler_type}"
	elif tc-is-clang; then
		package="llvm-core/${compiler_type}"
	else
		die "$(tc-get-compiler-type) compiler is not supported"
	fi

	package_version="${package}"

# 	eqawarn "asdf package_version: $package_version"

	ebegin "testing ${NVCC_CCBIN_default} (default)"

	while ! \
		nvcc "${NVCCFLAGS}" \
			-x cu \
			-ccbin "${NVCC_CCBIN}" \
			- \
			<<<"int main(){}" \
			&>> "${T}/cuda_get_host_compiler.log" ;
		do
		eend 1

		while true; do
			# prepare next version
			local package_version_next
			package_version_next="$(best_version "${package_version}")"

			if [[ -z "${package_version_next}" ]]; then
# 				eerror "$(cat "${T}/cuda_get_host_compiler.log")"
# 				eerror
				eerror "Compiler lookup failed. Nothing installed matches: ${package_version}."
				eerror "You can use NVCC_CCBIN to specify the exact compiler to use."
				eerror "Check ${T}/cuda_get_host_compiler.log for details."
				die "Could not find a supported version of ${compiler}. Did not find \"${package_version}\". NVCC_CCBIN is unset."
			fi

			package_version="<${package_version_next}"
# 			eqawarn "asdf package_version: $package_version"
			eqawarn "1 ${package_version/#<${package}-/}"
			eqawarn "2 ${package_version}"
			eqawarn "3 ${package}-"
			NVCC_CCBIN="${compiler}-$(ver_cut 1 "${package_version/#<${package}-/}")"
# 			eqawarn "NVCC_CCBIN: ${NVCC_CCBIN}"

			# skip the next version equals the already checked system default
			[[ "${NVCC_CCBIN}" != "${NVCC_CCBIN_default}" ]] && break
		done
		ebegin "testing ${NVCC_CCBIN}"
	done
	eend $?

	echo "${NVCC_CCBIN}"
	export NVCC_CCBIN
}

cuda_get_host_native_arch() {
	if [[ -v CUDAARCHS ]]; then
		echo "${CUDAARCHS}"
		return
	fi

	# TODO nvptx-arch ?
	__nvcc_device_query || die "failed to query the native device"
}

pkg_setup() {
	python-single-r1_pkg_setup
}

src_prepare () {
	# TODO maybe only old python?
	# sed -r \
	# 	-e 's#\\([()\^])#\\\\\1#g' \
	# 	-i \
	# 		cmake_modules/morse_cmake/modules/precision_generator/subs.py \
	# 		spm/cmake_modules/morse_cmake/modules/precision_generator/subs.py \
	# 	|| die

	cmake_src_prepare

	local PYTHON_SITE_DIR
	PYTHON_SITE_DIR=$(python_get_sitedir)

	sed \
		-e "s#[^:]*python\$#${PYTHON_SITE_DIR}#g" \
		-i spm/tools/spm_env.sh.in \
		|| die

	# sed \
	# 	-e "s#DESTINATION bin#DESTINATION $(get_bashcompdir)#" \
	# 	-i CMakeLists.txt \
	# 	|| die

	# sed \
	# 	-e "s#DESTINATION \${CMAKE_INSTALL_LIBDIR}/python#DESTINATION ${PYTHON_SITE_DIR}#g" \
	# 	-i \
	# 		wrappers/python/CMakeLists.txt \
	# 		spm/wrappers/python/CMakeLists.txt \
	# 	|| die
}

src_configure() {

	local mycmakeargs=(
		-DCMAKE_POLICY_DEFAULT_CMP0146="OLD" # BUG FindCUDA
		-DBLA_VENDOR="Generic"

		-DBUILDNAME="gentoo"

		-DBUILD_SHARED_LIBS="yes"
		-DBUILD_TESTING="$(usex test)"


		# -DINSTALL_EXAMPLES="$(usex examples)"
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

		-DLIB_INSTALL_DIR="$(get_libdir)"

		-DPython3_EXECUTABLE="${PYTHON}"
	)

	if use cuda; then
		cuda_add_sandbox -w

		# tc-is-gcc && cuda_check_compiler "gcc"
		# tc-is-clang && cuda_check_compiler "clang"

		# [[ -z "${CUDAARCHS}" ]] && einfo "trying to determine host CUDAARCHS"
		# : "${CUDAARCHS:=$(__nvcc_device_query)}"
		: "${CUDAARCHS:="$(cuda_get_host_native_arch)"}"
		export CUDAARCHS
		einfo "building for CUDAARCHS = ${CUDAARCHS}"

		local -x CUDAHOSTCXX CUDAHOSTLD
		CUDAHOSTCXX="$(cuda_get_host_compiler)"

		mycmakeargs+=(
			-DCUDA_NVCC_FLAGS="-ccbin ${CUDAHOSTCXX} -arch sm_${CUDAARCHS} -DCUDA_SM_VERSION=${CUDAARCHS}"
		)

	fi

	if ! use test; then
		# cmake_comment_add_subdirectory example
		cmake_comment_add_subdirectory test
		cmake_run_in spm cmake_comment_add_subdirectory tests
	fi

	cmake_src_configure
}

src_test() {
	local CMAKE_SKIP_TESTS=()

	if use cuda; then
		cuda_add_sandbox -w

		CMAKE_SKIP_TESTS+=(
			# Caught signal 11 (Segmentation fault: address not mapped to object at address 0x56551c24a0e0)
			# Caught signal 11 (Segmentation fault: address not mapped to object at address 0x55db93146be0)
			"^mpi_rep_example_simple_lap_c_facto3_sched1_1d$"
		)
	fi

	# if use python; then
	# 	CMAKE_SKIP_TESTS+=(
	# 		# https://docs.scipy.org/doc/scipy-1.12.0/reference/generated/scipy.linalg.tril.html
	# 		# AttributeError: module 'scipy.linalg' has no attribute 'tril'
	# 		"^python_shm_schur$"
	# 	)
	# fi

	cmake_src_test
}

src_install() {
	cmake_src_install

	mv "${ED}/usr/share/doc/"{"${PN}","${PF}"} || die
	mv "${ED}/usr/share/doc/"spm{,-1.2.4} || die

	use python && python_optimize
}
