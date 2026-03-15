# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

LLVM_COMPAT=( {21..23} )
LLVM_OPTIONAL="clang-cuda"

PYTHON_COMPAT=( python3_{12..13} )

FORTRAN_NEEDED="no"

LAPACK_ADDONS_PV="3.4.1"

inherit cmake cuda flag-o-matic fortran-2 llvm-r2 python-any-r1 toolchain-funcs
# inherit virtualx

DESCRIPTION="C++ template library for linear algebra"
HOMEPAGE="https://eigen.tuxfamily.org/index.php?title=Main_Page"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.com/lib${PN}/${PN}.git"
	if [[ ${PV} = *.9999* ]] ; then
		EGIT_BRANCH="$(ver_cut 1-2)"
	fi
else
	SRC_URI="
		https://gitlab.com/lib${PN}/${PN}/-/archive/${PV}/${P}.tar.bz2
	"
	KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86 ~arm64-macos ~x64-macos"
fi

SRC_URI+="
	test? (
		lapack? (
			https://downloads.tuxfamily.org/${PN}/lapack_addons_${LAPACK_ADDONS_PV}.tgz
				-> ${PN}-lapack_addons-${LAPACK_ADDONS_PV}.tgz
		)
	)
"

LICENSE="MPL-2.0"
SLOT="3/$(ver_cut 1-2)"

# The following lines are shamelessly stolen from ffmpeg-9999.ebuild with modifications
ARM_CPU_FEATURES=(
	neon:NEON
)
PPC_CPU_FEATURES=(
	altivec:ALTIVEC
	vsx:VSX
)
X86_CPU_FEATURES=(
	avx:AVX
	avx2:AVX2
	avx512f:AVX512
	avx512dq:AVX512DQ
	f16c:FP16C
	fma3:FMA
	popcnt:POPCNT
	sse:SSE
	sse2:SSE2
	sse3:SSE3
	ssse3:SSSE3
	sse4_1:SSE4_1
	sse4_2:SSE4_2
)
# MIPS_CPU_FEATURES=(
# 	msa:MSA
# )
# S390_CPU_FEATURES=(
# 	z13:Z13
# 	z14:Z14
# )

CPU_FEATURES_MAP=(
	"${ARM_CPU_FEATURES[@]/#/cpu_flags_arm_}"
	"${PPC_CPU_FEATURES[@]/#/cpu_flags_ppc_}"
	"${X86_CPU_FEATURES[@]/#/cpu_flags_x86_}"
	# "${MIPS_CPU_FEATURES[@]/#/cpu_flags_mips_}"
	# "${S390_CPU_FEATURES[@]/#/cpu_flags_s390_}"
)

IUSE_TEST_BACKENDS=(
	"adolc" # Adolc
	"boost" # Boost.Multiprecision
	"cholmod" # CHOLMOD
	# "ducc" # duccfft https://gitlab.mpcdf.mpg.de/mtr/ducc
	"fftw" # fftw
	"klu" # KLU
	"metis" # METIS
	# "mpreal" # MPFR C++ https://github.com/advanpix/mpreal
	"opengl" # OpenGL
	"pocketfft" # pocketfft
	"pastix" # PaStiX
	"sparsehash" # GoogleHash
	"spqr" # SPQR
	"superlu" # SuperLU
	"umfpack" # UMFPACK
	# "qt" # Qt4 support
	# Accelerate # https://developer.apple.com/documentation/accelerate
)

IUSE="
	debug
	blas lapack
	${CPU_FEATURES_MAP[*]%:*}
	cuda clang-cuda hip
	doc mathjax
	openmp
	test ${IUSE_TEST_BACKENDS[*]}
" # zvector
# IUSE+="
# 	benchmark
# 	demos
# "

RESTRICT_TEST="
	test? (
		^^ (
			cuda
			( cuda clang-cuda )
			hip
		)
		^^ (
			^^ (
				${IUSE_TEST_BACKENDS[*]}
			)
			(
				${IUSE_TEST_BACKENDS[*]}
			)
		)
	)
	|| (
		( !doc !mathjax )
		doc
		( doc mathjax )
	)
	|| (
		( !blas !lapack )
		blas
		( blas lapack )
	)
"

REQUIRED_USE="
	test? (
		clang-cuda? ( ${LLVM_REQUIRED_USE} )
	)
	lapack? (
		blas
	)
	clang-cuda? (
		!openmp
	)
"
# 	test? (
# 		|| ( ${IUSE_TEST_BACKENDS[*]} )
# 	${RESTRICT_TEST}

# {{{
# test
# }}}

# {{{
#
# cuda
# cuda clang-cuda
# hip
# }}}

# {{{
#
# doc
# doc mathjax
# }}}

# {{{
#
# openmp
# }}}

# {{{
	# {{{
	# adolc
	# boost
	# cholmod
	# fftw
	# klu
	# metis
	# opengl
	# pocketfft
	# pastix
	# sparsehash
	# spqr
	# superlu
	# umfpack
	# }}}
	# {{{
	# adolc boost cholmod fftw klu metis opengl pocketfft pastix sparsehash spqr superlu umfpack
	# }}}
# }}}

# Tests failing again because of compiler issues; bugs #932646, #943401
RESTRICT="!test? ( test )"
FORTRAN_DEPEND="virtual/fortran"

BDEPEND="
	doc? (
		app-text/doxygen[dot]
		dev-texlive/texlive-bibtexextra
		dev-texlive/texlive-fontsextra
		dev-texlive/texlive-fontutils
		dev-texlive/texlive-latex
		dev-texlive/texlive-latexextra
		mathjax? ( dev-libs/mathjax )
	)
	test? (
		virtual/pkgconfig
		lapack? (
			${PYTHON_DEPS}
		)
		spqr? (
			cholmod? (
				blas? (
					lapack? (
						${FORTRAN_DEPEND}
					)
				)
			)
		)
		pastix? ( ${FORTRAN_DEPEND} )
	)
	blas? ( ${FORTRAN_DEPEND} )
	lapack? ( ${FORTRAN_DEPEND} )
"

TEST_BACKENDS="
		adolc? ( sci-libs/adolc[sparse] )
		boost? ( dev-libs/boost )
		cholmod? ( sci-libs/cholmod:=[cuda?] )
		fftw? ( sci-libs/fftw[openmp?] )
		klu? ( sci-libs/klu )
		metis? (
			sci-libs/metis[openmp?]
			sci-libs/pastix[metis]
		)
		opengl? (
			media-libs/freeglut
			media-libs/glew
			media-libs/libglvnd
		)
		pastix? (
			sci-libs/pastix[-mpi]
			|| (
				sci-libs/pastix[scotch]
				sci-libs/pastix[metis]
			)
		)
		pocketfft? ( dev-libs/pocketfft )
		sparsehash? (
			amd64? ( dev-cpp/sparsehash )
			arm64? ( dev-cpp/sparsehash )
			ppc64? ( dev-cpp/sparsehash )
			x86?   ( dev-cpp/sparsehash )
		)
		spqr? ( sci-libs/spqr )
		superlu? ( sci-libs/superlu )
		umfpack? ( sci-libs/umfpack:= )
"

# +find_package(MPFR)
# +find_package(GMP)

DEPEND="
	test? (
		cuda? (
			!clang-cuda? (
				dev-util/nvidia-cuda-toolkit
			)
			clang-cuda? (
				$(llvm_gen_dep '
					llvm-core/clang:${LLVM_SLOT}
					llvm-runtimes/clang-runtime:${LLVM_SLOT}[llvm_targets_NVPTX,offload,openmp]
				')
			)
		)
		hip? ( dev-util/hip )
		!blas? (
			virtual/blas
			!lapack? (
				virtual/lapacke
			)
		)
		${TEST_BACKENDS}
	)
"
# DEPEND+="
# 	benchmark? (
# 		dev-cpp/benchmark
# 	)
# "

PATCHES=(
	"${FILESDIR}/${PN}-3.4.0-doc-nocompress.patch" # bug 830064
	"${FILESDIR}/${PN}-3.4.0-buildstring.patch"
	"${FILESDIR}/${PN}-3.4.1-cxxstandard-17.patch"

	"${FILESDIR}/${PN}-3.4.0-c++-20.patch"
	"${FILESDIR}/${PN}-3.4.1-bug1213-link-with-Eigen3-Eigen.patch"

	"${FILESDIR}/${PN}-5.0.1-Do-not-show-deprecated-CUDA-device-properties-for-CU.patch"
	# "${FILESDIR}/${PN}-3.4.1-error-no-matching-function-for-call-to-get_test_prec.patch"
	# "${FILESDIR}/${PN}-3.4.1-fix-TriangularSolverMatrix.patch"
	"${FILESDIR}/${PN}-5.0.1-cmake-GNUInstallDirs.patch"
)

# TODO should be in cuda.eclass
cuda_set_CUDAHOSTCXX() {
	local compiler
	tc-is-gcc && compiler="gcc"
	tc-is-clang && compiler="clang"
	[[ -z "$compiler" ]] && die "no compiler specified"

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
			which "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
		)"
		version="<${version}"
	do ! echo "int main(){}" | nvcc "-ccbin ${CUDAHOSTCXX_test}" - -x cu &>/dev/null; done

	export CUDAHOSTCXX
	echo "${CUDAHOSTCXX}"
}

pkg_setup() {
	if use lapack; then
		python-any-r1_pkg_setup
	fi

	if { use test && { use spqr && use cholmod && use blas && use lapack; } || use pastix; } \
		|| use blas \
		|| use lapack \
		; then
		fortran-2_pkg_setup
	fi

	if use test; then
		use cuda && use clang-cuda && llvm-r2_pkg_setup
	fi
}

src_unpack() {
	if [[ ${PV} = *9999* ]] ; then
		git-r3_src_unpack
	else
		unpack "${P}.tar.bz2"
	fi

	if use test && use lapack; then
		pushd "${S}/lapack" > /dev/null || die
		unpack "${PN}-lapack_addons-${LAPACK_ADDONS_PV}.tgz"
		popd > /dev/null || die

		pushd "${S}" > /dev/null || die
		eapply "${FILESDIR}/${PN}-5.0.1-fix-lapack_testing.py.patch"
		popd > /dev/null || die
	fi
}

src_prepare() {
	if ! in_iuse benchmark || ! use benchmark; then
		rm -r bench || die
		cmake_comment_add_subdirectory bench/spbench
	fi

	if ! in_iuse demos || ! use demos; then
		rm -r demos || die
		cmake_comment_add_subdirectory demos
	fi

	# run patches here as we patch in test/
	cmake_src_prepare

	if false && ! use test; then
		sed \
			-e "/add_subdirectory(test/s/^/#DONOTCOMPILE /g" \
			-e "/add_subdirectory(scripts/s/^/#DONOTCOMPILE /g" \
			-e "/add_subdirectory(failtest/s/^/#DONOTCOMPILE /g" \
			-e "/add_subdirectory(blas/s/^/#DONOTCOMPILE /g" \
			-e "/add_subdirectory(lapack/s/^/#DONOTCOMPILE /g" \
			-i CMakeLists.txt || die

		# scripts
		# scripts/cdashtesting.cmake.in
		rm -r test failtest blas lapack || die
	fi
}

src_configure() {
	if use lapack; then
		# multiple definition of `cgesdd_'
		filter-lto
	fi

	local mycmakeargs=(
		-DCMAKE_CXX_STANDARD="20"
		-DCMAKE_POSITION_INDEPENDENT_CODE="yes"

		-DEIGEN_BUILD_TESTING="$(usex test)" # Enable creation of Eigen tests.

		-DEIGEN_BUILD_BLAS="$(usex blas)" # Toggles the building of the Eigen Blas library
		-DEIGEN_BUILD_LAPACK="$(usex blas "$(usex lapack)")" # Toggles the building of the included Eigen LAPACK library

		# -DEIGEN_BUILD_BTL="$(usex benchmark)" # Build benchmark suite # TODO GONE
		# -DEIGEN_BUILD_SPBENCH="no" # "$(usex spbench)" # Build sparse benchmark suite # TODO GONE

		# -DEIGEN_BUILD_AOCL_BENCH="no" # "$(usex aocl-bench)" # "Build AOCL benchmark" # not in 5.0.0

		-DEIGEN_BUILD_DOC="$(usex doc)" # Enable creation of Eigen documentation
		# -DEIGEN_BUILD_DEMOS="$(usex demos)" # Toggles the building of the Eigen demos
	)

	append-cxxflags "-DEIGEN_USE_OPENBLAS_BFLOAT16=0"

	# if use benchmarks; then
	# 	# TODO in unsupported/benchmarks !?
	# 	:
	# fi

	if use blas; then
		mycmakeargs+=(
			-DBUILD_SHARED_LIBS="yes"
			-DEIGEN_BUILD_SHARED_LIBS="yes"
			-DEIGEN_BUILD_STATIC_LIBS="yes"
			-DEIGEN_INSTALL_STATIC_LIBS="yes"
		)

		if use lapack; then
			mycmakeargs+=(
				-DCMAKE_POLICY_DEFAULT_CMP0148="OLD" # FindPythonInterp
				-DEIGEN_ENABLE_LAPACK_TESTS="$(usex test)"

				# -DCMAKE_DISABLE_FIND_PACKAGE_SuperLU=ON # TODO
			)
		fi
	fi

	if use doc || use test; then # || use demos
		mycmakeargs+=(
			# needs Qt4
			-DEIGEN_TEST_NOQT="yes" # Disable Qt support in unit tests
		)
	fi

	if use doc; then
		mycmakeargs+=(
			-DEIGEN_DOC_USE_MATHJAX="$(usex mathjax)" # Use MathJax for rendering math in HTML docs
			-DEIGEN_INTERNAL_DOCUMENTATION="no" # Build internal documentation
		)
	fi

	if use test; then
		# bug 878987
		# filter-lto

		# append-cxxflags "-DEIGEN_COMP_CLANG_STRICT=$(usex debug 1 0)"
		# append-cxxflags "-DEIGEN_NO_STATIC_ASSERT"

		mycmakeargs+=( # {{{
			-DEIGEN_LEAVE_TEST_IN_ALL_TARGET="yes" # Leaves tests in the all target, needed by ctest for automatic building

			# the OpenGL testsuite is extremely brittle, bug #712808
			-DEIGEN_TEST_OPENGL="$(usex opengl)" # Enable OpenGL support in unit tests
			-DEIGEN_TEST_OPENMP="$(usex openmp)" # Enable/Disable OpenMP in tests/examples

			-DEIGEN_TEST_EXTERNAL_BLAS="$(usex !blas)" # Use external BLAS library for testsuite # TODO

			# -DEIGEN_TEST_CUSTOM_CXX_FLAGS="-fPIC" # Additional compiler flags when compiling unit tests.
			# -DEIGEN_TEST_CUSTOM_LINKER_FLAGS="-fPIC" # Additional linker flags when linking unit tests.
			# -DEIGEN_TEST_BUILD_FLAGS="-fPIC" # Options passed to the build command of unit tests

			-DEIGEN_TEST_BUILD_DOCUMENTATION="no" # $(usex doc)" # Test building the doxygen documentation

			# -DEIGEN_COVERAGE_TESTING="no" # Enable/disable gcov
			# -DEIGEN_CTEST_ERROR_EXCEPTION="" # Regular expression for build error messages to be filtered out
			-DEIGEN_DEBUG_ASSERTS="$(usex debug)" # Enable advanced debugging of assertions
			# -DEIGEN_NO_ASSERTION_CHECKING="no" # Disable checking of assertions using exceptions
			# -DEIGEN_TEST_NO_EXCEPTIONS="no" # Disables C++ exceptions
			# -DEIGEN_TEST_NO_EXPLICIT_ALIGNMENT="no" # Disable explicit alignment (hence vectorization) in tests/examples
			# -DEIGEN_TEST_NO_EXPLICIT_VECTORIZATION="no" # Disable explicit vectorization in tests/examples

			# -DEIGEN_DASHBOARD_BUILD_TARGET="buildtests" # Target to be built in dashboard mode, default is buildtests

			# -DEIGEN_DEFAULT_TO_ROW_MAJOR="no" # Use row-major as default matrix storage order

			# -DEIGEN_TEST_MATRIX_DIR="yes" # Enable testing of realword sparse matrices contained in the specified path
			# -DEIGEN_TEST_MAX_SIZE="320" # Maximal matrix/vector size, default is 320
			# we do this so we can skip failing subtests
			-DEIGEN_SPLIT_LARGE_TESTS="yes" # Split large tests into smaller executables

			-DEIGEN_TEST_CUDA="$(usex cuda)" # Enable CUDA support in unit tests
			-DEIGEN_TEST_CUDA_CLANG="$(usex cuda "$(usex clang-cuda)")" # Use clang instead of nvcc to compile the CUDA tests

			-DEIGEN_TEST_HIP="$(usex hip)" # Add HIP support.

			# -DEIGEN_TEST_SYCL="$(usex sycl)" # Add Sycl support.
			# -DEIGEN_SYCL_TRISYCL="no" # Use the triSYCL Sycl implementation (ComputeCPP by default).

			$(cmake_use_find_package adolc Adolc)
			$(cmake_use_find_package boost Boost)
			$(cmake_use_find_package cholmod CHOLMOD)
			$(cmake_use_find_package fftw FFTW )
			$(cmake_use_find_package klu KLU)
			-DCMAKE_DISABLE_FIND_PACKAGE_MPREAL="yes"
			# $(cmake_use_find_package opengl OpenGL) # EIGEN_TEST_OPENGL
			# $(cmake_use_find_package openmp OpenMP) # EIGEN_TEST_OPENMP
			$(cmake_use_find_package pastix PASTIX)
			# prevent pastix_nompi.h lookup it no longer exists, we enforce this via deps
			-DPASTIX_pastix_nompi.h_INCLUDE_DIRS="FOUND"

			$(cmake_use_find_package sparsehash GoogleHash)
			$(cmake_use_find_package spqr SPQR)
			$(cmake_use_find_package superlu SuperLU)
			$(cmake_use_find_package umfpack UMFPACK)
		) # }}}

		# use !adolc      && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_Adolc="TRUE" )
		# use !boost      && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_Boost="TRUE" )
		# use !cholmod    && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_CHOLMOD="TRUE" )
		# use !fftw       && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_FFTW="TRUE" )
		# use !klu        && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_KLU="TRUE" )
		# # use !opengl     && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_OpenGL="TRUE" ) # EIGEN_TEST_OPENGL
		# # use !openmp     && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_OpenMP="TRUE" ) # EIGEN_TEST_OPENMP
		# use !pastix     && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_PASTIX="TRUE" )
		# use !sparsehash && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_GoogleHash="TRUE" )
		# use !spqr       && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_SPQR="TRUE" )
		# use !superlu    && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_SuperLU="TRUE" )
		# use !umfpack    && mycmakeargs+=( -DCMAKE_DISABLE_FIND_PACKAGE_UMFPACK="TRUE" )

		if use arm; then
			mycmakeargs+=(
				-DEIGEN_TEST_NEON="$(usex cpu_flags_arm_neon)"
			)
		fi

		if use arm64; then
			mycmakeargs+=(
				-DEIGEN_TEST_NEON64="$(usex cpu_flags_arm_neon)"
			)
		fi

		if use amd64 || use x86; then
			mycmakeargs+=(
				# -DEIGEN_TEST_32BIT=no # Force generating 32bit code.
				# -DEIGEN_TEST_X87=no # Force using X87 instructions. Implies no vectorization.
				-DEIGEN_TEST_SSE2="$(usex cpu_flags_x86_sse2)"
				-DEIGEN_TEST_SSE3="$(usex cpu_flags_x86_sse3)"
				-DEIGEN_TEST_SSSE3="$(usex cpu_flags_x86_ssse3)"
				-DEIGEN_TEST_FMA="$(usex cpu_flags_x86_fma3)"
				-DEIGEN_TEST_SSE4_1="$(usex cpu_flags_x86_sse4_1)"
				-DEIGEN_TEST_SSE4_2="$(usex cpu_flags_x86_sse4_2)"
				-DEIGEN_TEST_AVX="$(usex cpu_flags_x86_avx)"
				-DEIGEN_TEST_F16C="$(usex cpu_flags_x86_f16c)"
				-DEIGEN_TEST_AVX2="$(usex cpu_flags_x86_avx2)"
				-DEIGEN_TEST_AVX512="$(usex cpu_flags_x86_avx512f)"
				-DEIGEN_TEST_AVX512DQ="$(usex cpu_flags_x86_avx512dq)"
			)
		fi

		if use mips; then
			mycmakeargs+=(
				# -DEIGEN_TEST_MSA=no # Enable/Disable MSA in tests/examples
			)
		fi

		if use ppc || use ppc64; then
			mycmakeargs+=(
				-DEIGEN_TEST_ALTIVEC="$(usex cpu_flags_ppc_altivec)"
				-DEIGEN_TEST_VSX="$(usex cpu_flags_ppc_vsx)"
			)
		fi

		if use s390; then
			mycmakeargs+=(
				# -DEIGEN_TEST_Z13=no # Enable/Disable S390X(zEC13) ZVECTOR in tests/examples
				# -DEIGEN_TEST_Z14=no # Enable/Disable S390X(zEC14) ZVECTOR in tests/examples
			)
		fi

		if use cuda; then
			cuda_add_sandbox -w

			if use clang-cuda; then
				local llvm_prefix
				llvm_prefix="$(get_llvm_prefix -b)"

				# NVCCFLAGS gets injected into CMAKE_CXX_FLAGS, which means we need to use clang as gcc will fail with
				# error: unrecognized command-line option
				if ! tc-is-clang; then
					export CC="${CHOST}-clang-${LLVM_SLOT}"
					export CXX="${CHOST}-clang++-${LLVM_SLOT}"
				fi

				NVCCFLAGS="${NVCCFLAGS:+${NVCCFLAGS} }--libomptarget-nvptx-bc-path=${llvm_prefix}/$(get_libdir)/nvptx64-nvidia-cuda/libomptarget-nvptx.bc"

				mycmakeargs+=(
					-DCUDA_HOST_COMPILER="${CHOST}-clang++-${LLVM_SLOT}"
				)
			else
				cuda_set_CUDAHOSTCXX

				mycmakeargs+=(
					-DCUDA_HOST_COMPILER="${CUDAHOSTCXX}"
				)
				if [[ -v CUDACXX ]]; then
					mycmakeargs+=(
						-DCUDA_NVCC_EXECUTABLE="${CUDACXX}"
					)
				fi
			fi

			if [[ "${CUDA_VERBOSE}" == true ]]; then
				mycmakeargs+=(
					-DCUDA_VERBOSE_BUILD="yes"
				)
				NVCCFLAGS+=" -v"
			fi

			[[ -z "${CUDAARCHS}" ]] && einfo "trying to determine host CUDAARCHS"
			if use clang-cuda; then
				: "${CUDAARCHS:=$(nvptx-arch || die "nvptx-arch")}"
				CUDAARCHS="${CUDAARCHS//sm_/}"
			else
				: "${CUDAARCHS:=$(__nvcc_device_query || die "__nvcc_device_query")}"
			fi
			export CUDAARCHS

			# CUDAFLAGS is used by cmake
			# NVCCFLAGS is used by cuda.eclass
			mycmakeargs+=(
				-DEIGEN_CUDA_COMPUTE_ARCH="${CUDAARCHS}" # TODO this needs to be lowest first

				# TODO
				# for test/CMakeLists.txt
				# -DEIGEN_TEST_CUSTOM_CXX_FLAGS="${NVCCFLAGS}"

				# for {,unsupported/}test/CMakeLists.txt
				# affects nvcc and cuda-clang
				-DEIGEN_CUDA_CXX_FLAGS="${NVCCFLAGS}"
				# affects nvcc only
				# -DCUDA_NVCC_FLAGS=

				# -DCUDA_PROPAGATE_HOST_FLAGS="yes"
				-DCUDA_USE_STATIC_CUDA_RUNTIME="yes"
			)
		fi

		if use opengl; then
			mycmakeargs+=(
				-DOpenGL_GL_PREFERENCE="GLVND"
			)
		fi

		if use pocketfft; then
			mycmakeargs+=(
				-DEIGEN_TEST_CXX11="yes"
			)
		fi
	fi

	cmake_src_configure
}

src_compile() {
	local targets=()

	if use blas; then
		targets+=( blas )
		if use lapack; then
			targets+=( lapack )
		fi
	fi

	if use test; then
		targets+=( buildtests )

		# tests generate random data, which obviously fails for some seeds
		# export EIGEN_SEED=712808
	fi

	# we add doc last to capture results for buildtests
	if use doc; then
		targets+=( doc )
		# HTML_DOCS=( "${BUILD_DIR}/doc/html/." )
	fi

	# EIGEN_IS_BUILDING_
	# if use test || use blas || use lapack || use benchmark || use spbench || use doc || use demos; then
	if [[ -n "${targets[*]}" ]]; then
		cmake_src_compile "${targets[@]}"
	fi
}

src_test() {
	local CMAKE_SKIP_TESTS=(
		# "^schur_complex$"

		"^basicstuff_8$" # Official # 1

		"^matrix_power_8$" # Unsupported # 1
		"^matrix_power_11$" # Unsupported # 1
		"^matrix_square_root_3$" # Unsupported # 1

		"^ref$"
		"^ref_8$" # Official # 1

		"^matrix_square_root_1$"

		# # smoketest
		# "^mixingtypes_2$" # Official
		# "^mixingtypes_3$" # Official
		# "^mixingtypes_5$" # Official
		# "^mixingtypes_6$" # Official
	)

	if use cholmod; then
		CMAKE_SKIP_TESTS+=(
		"^cholmod_support$"
		"^cholmod_support_21$" # 1
		"^cholmod_support_22$" # 1
		)
	fi

	if use cuda; then
		cuda_add_sandbox -w

		CMAKE_SKIP_TESTS+=(
			"^cxx11_tensor_gpu$"
			# we rerun these til they pass
			# "^cxx11_tensor_reduction_gpu_1$" # Unsupported gpu
			# "^cxx11_tensor_gpu_4$" # Unsupported gpu
			# "^cxx11_tensor_gpu_6$" # Unsupported gpu
			# "^cxx11_tensor_gpu_7$" # Unsupported gpu
		)

		if use boost; then
			CMAKE_SKIP_TESTS+=(
				# "^boostmultiprec_6$" # Official # 2
			)
		fi
	fi

	if use lapack; then
		CMAKE_SKIP_TESTS+=(
			"^LAPACK-xlintsts_stest_in$" # 1
			"^LAPACK-xeigtsts_sep_in$" # 1
			"^LAPACK-xeigtsts_svd_in$" # 1
			"^LAPACK-xlintstd_dtest_in$" # 1
			"^LAPACK-xeigtstd_sep_in$" # 1
			"^LAPACK-xeigtstd_svd_in$" # 1
			"^LAPACK-xlintstc_ctest_in$" # 1
			"^LAPACK-xeigtstc_svd_in$" # 1
			# "^LAPACK_Test_Summary$" # 1
		)
	fi

	if use klu; then
		CMAKE_SKIP_TESTS+=(
			"^klu_support$"
			"^klu_support_1$" # 1
			"^klu_support_2$" # 1
		)
	fi

	if [[ -v CMAKE_SKIP_TESTS ]]; then
		eqawarn "tests skipped:"
		eqawarn "${CMAKE_SKIP_TESTS[@]}"
	fi

	local myctestargs=(
		-j1 # otherwise breaks due to cmake reruns
		--repeat until-pass:15
		# --repeat until-fail:10
		# --output-on-failure
		# -LE '(gpu|smoketest)'
	)

	# virtx \
		cmake_src_test
}

src_install() {
	local DOCS=()
	cmake_src_install

	if use doc; then
		pushd "${BUILD_DIR}/doc" > /dev/null || die
		dodoc -r html
		popd > /dev/null || die
	fi
}
