# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )

inherit cuda cmake python-any-r1 flag-o-matic toolchain-funcs

DESCRIPTION="CUDA Templates for Linear Algebra Subroutines"
HOMEPAGE="https://github.com/NVIDIA/cutlass"
SRC_URI="https://github.com/NVIDIA/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

X86_CPU_FEATURES=(
	f16c:f16c
)
CPU_FEATURES=( "${X86_CPU_FEATURES[@]/#/cpu_flags_x86_}" )

IUSE="clang-cuda cublas cudnn doc dot examples +headers-only jumbo-build performance profiler test tools ${CPU_FEATURES[*]%:*}"

REQUIRED_USE="
	headers-only? (
		!examples !test
	)
"

RESTRICT="!test? ( test )"

RDEPEND="
	dev-util/nvidia-cuda-toolkit:=
"
DEPEND="${RDEPEND}
	test? (
		${PYTHON_DEPS}
		cudnn? (
			dev-libs/cudnn:=
		)
	)
	tools? (
		${PYTHON_DEPS}
	)
"

pkg_setup() {
	if use test || use tools; then
		python-any-r1_pkg_setup
	fi
}

src_prepare() {
	cmake_src_prepare

	sed \
		-e '/-std=/s/17/20/g' \
		-e '/CMAKE_CXX_STANDARD/s/17/20/g' \
		-e '/CMAKE_CUDA_STANDARD/s/17/20/g' \
		-i \
			CMakeLists.txt \
			python/cutlass/backend/compiler.py \
			python/cutlass/emit/pytorch.py \
			python/docs/_modules/cutlass/emit/pytorch.html \
			test/unit/nvrtc/thread/nvrtc_contraction.cu \
			test/unit/nvrtc/thread/testbed.h \
			media/docs/cpp/ide_setup.md \
		|| die

	sed \
		-e 's/cxx_std_17/cxx_std_20/g' \
		-i \
			tools/library/CMakeLists.txt \
		|| die
}

src_configure() {
	# we can use clang as default
	if use clang-cuda && ! tc-is-clang ; then
		export CC="${CHOST}-clang"
		export CXX="${CHOST}-clang++"
	else
		tc-export CXX CC
	fi

	# clang-cuda needs to filter mfpmath
	if use clang-cuda ; then
		filter-mfpmath sse
		filter-mfpmath i386
	fi
	if use clang-cuda ; then
		export CUDACXX=clang++
	fi

	cuda_src_prepare
	cuda_src_configure

	local mycmakeargs=(
		-DCMAKE_POLICY_DEFAULT_CMP0156="OLD" # cutlass_add_library

		# -DCMAKE_CUDA_COMPILER="$(cuda_get_host_compiler)" # nvcc/clang++
		-DCMAKE_CUDA_FLAGS="$(cuda_gccdir -f)"

		-DCMAKE_DISABLE_FIND_PACKAGE_Doxygen="$(usex !doc)"

		# Utilize profiler-based functional regressions
		# -DCUTLASS_BUILD_FOR_PROFILER_REGRESSIONS=OFF

		# Enable/Disable rigorous conv problem sizes in conv unit tests
		# -DCUTLASS_CONV_UNIT_TEST_RIGOROUS_SIZE_ENABLED=ON

		# Level of debug tracing to perform.
		# -DCUTLASS_DEBUG_TRACE_LEVEL=0

		# Default activated test sets. In `make test` mode, this string determines the active set of tests.
		# In `ctest` mode, this value can be overriden with CUTLASS_TEST_SETS environment variable when running the ctest
		# executable.
		# -DCUTLASS_DEFAULT_ACTIVE_TEST_SETS=default

		# CUTLASS Repository Directory
		# -DCUTLASS_DIR=/var/tmp/paludis/dev-libs-cutlass-3.9.0/work/cutlass-3.9.0

		# cuBLAS usage for tests
		-DCUTLASS_ENABLE_CUBLAS="$(usex cublas)"

		# cuDNN usage for tests
		-DCUTLASS_ENABLE_CUDNN="$(usex cudnn)"

		# Enable CUTLASS Examples
		-DCUTLASS_ENABLE_EXAMPLES="$(usex examples)"

		# Enable F16C x86 extensions in host code.
		-DCUTLASS_ENABLE_F16C="$(usex cpu_flags_x86_f16c)"

		# Enables Grid Dependency Control (GDC) for SM100 kernels (required for PDL).
		# -DCUTLASS_ENABLE_GDC_FOR_SM100=ON

		# Enable CUTLASS GTest-based Unit Tests
		-DCUTLASS_ENABLE_GTEST_UNIT_TESTS="$(usex test)"

		# Enable only the header library
		-DCUTLASS_ENABLE_HEADERS_ONLY="$(usex headers-only)"

		# Enable CUTLASS Library
		-DCUTLASS_ENABLE_LIBRARY="$(usex !headers-only)"

		# Enable CUTLASS Performance
		-DCUTLASS_ENABLE_PERFORMANCE="$(usex performance)"

		# Enable CUTLASS Profiler
		-DCUTLASS_ENABLE_PROFILER="$(usex profiler)"

		# Enable CUTLASS Profiler-based Unit Tests
		-DCUTLASS_ENABLE_PROFILER_UNIT_TESTS="$(usex test "$(usex profiler)")"

		# Enable CUTLASS check for self-contained header includes
		# -DCUTLASS_ENABLE_SELF_CONTAINED_INCLUDES_CHECK=ON

		# Enable an extended set of SM90 WGMMA instruction shapes (may lead to increased compilation times)
		# -DCUTLASS_ENABLE_SM90_EXTENDED_MMA_SHAPES=OFF

		# Enable synchronization event logging for race condition debugging. WARNING: This redefines __syncthreads() and
		# __syncwarp() in all downstream code!
		# -DCUTLASS_ENABLE_SYNCLOG=OFF

		# Enable PTX mma instruction for collective matrix multiply operations.
		# -DCUTLASS_ENABLE_TENSOR_CORE_MMA=ON

		# Enable CUTLASS Tests
		-DCUTLASS_ENABLE_TESTS="$(usex test)"

		# Enable CUTLASS Tools
		-DCUTLASS_ENABLE_TOOLS="$(usex tools)"

		# Using GNU tools for host code compilation
		# -DCUTLASS_GNU_HOST_COMPILE=ON

		# Install test executables
		-DCUTLASS_INSTALL_TESTS="no"

		# Default postfix value for debug libraries
		# -DCUTLASS_LIBRARY_DEBUG_POSTFIX=.debug

		# Comma-delimited list of kernels to exclude from build. This option always takes effect, whether or not
		# CUTLASS_LIBRARY_KERNELS is set. It also can exclude kernels from the filter file (see KERNEL_FILTER_FILE).
		# -DCUTLASS_LIBRARY_EXCLUDE_KERNELS=

		# Comma-delimited list of kernels to exclude from build.
		# This option ONLY takes effect if CUTLASS_LIBRARY_KERNELS is set.
		# -DCUTLASS_LIBRARY_IGNORE_KERNELS=

		# Instantiation level for SM90 kernels.
		# Set to `max` and make sure CUTLASS_LIBRARY_KERNELS is non-empty to stamp all possible kernel configurations.
		# -DCUTLASS_LIBRARY_INSTANTIATION_LEVEL=

		# Comma-delimited list of kernel name filters.
		# If unspecified, only the largest tile size is enabled. If the string 'all' is specified, all kernels are enabled.
		# -DCUTLASS_LIBRARY_KERNELS=

		# Comma-delimited list of operation name filters. Default '' means all operations are enabled.
		# -DCUTLASS_LIBRARY_OPERATIONS=all

		# Top level namespace of CUTLASS
		# -DCUTLASS_NAMESPACE=cutlass

		# The SM architectures requested.
		-DCUTLASS_NVCC_ARCHS="${CUDAARCHS}"

		# The SM architectures to build code for.
		# -DCUTLASS_NVCC_ARCHS_ENABLED="70;72;75;80;86;87;89;90;90a;100;100a;101;101a;120;120a"

		# Using nvcc tools for device compilation
		# -DCUTLASS_NVCC_DEVICE_COMPILE=ON

		# Embed compiled CUDA kernel binaries into executables.
		# -DCUTLASS_NVCC_EMBED_CUBIN=ON

		# Embed compiled PTX into executables.
		# -DCUTLASS_NVCC_EMBED_PTX=ON

		# Keep intermediate files generated by NVCC.
		# -DCUTLASS_NVCC_KEEP=OFF

		# Disable compilation of reference kernels in the CUTLASS profiler.
		# -DCUTLASS_PROFILER_DISABLE_REFERENCE=OFF

		# Profiler functional regression test level
		# -DCUTLASS_PROFILER_REGRESSION_TEST_LEVEL=0

		# Disable init reduction workspace
		# -DCUTLASS_SKIP_REDUCTION_INIT=OFF

		# Enable caching and reuse of test results in unit tests
		# -DCUTLASS_TEST_ENABLE_CACHED_RESULTS=ON

		# Environment in which to invoke unit test executables
		# -DCUTLASS_TEST_EXECUTION_ENVIRONMENT=

		# Test root install location, relative to CMAKE_INSTALL_PREFIX.
		# -DCUTLASS_TEST_INSTALL_BINDIR=test/cutlass/bin

		# Test root install location, relative to CMAKE_INSTALL_PREFIX.
		# -DCUTLASS_TEST_INSTALL_LIBDIR=test/cutlass/lib64

		# Test root install location, relative to CMAKE_INSTALL_PREFIX.
		# -DCUTLASS_TEST_INSTALL_PREFIX=test/cutlass

		# Enable warnings on waived unit tests.
		# -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=OFF

		# Batch size for unified source files
		# -DCUTLASS_UNITY_BUILD_BATCH_SIZE=16

		# Enable combined source compilation
		-DCUTLASS_UNITY_BUILD_ENABLED="$(usex jumbo-build)"

		# Use system/external installation of GTest
		-DCUTLASS_USE_SYSTEM_GOOGLETEST="yes"

		# Do not explicitly specify -std=c++17 if set
		-DIMPLICIT_CMAKE_CXX_STANDARD="yes"

		# KERNEL FILTER FILE FULL PATH
		# -DKERNEL_FILTER_FILE=

		# Name of the filtered kernel list
		# -DSELECTED_KERNEL_LIST=selected
	)

	if use doc; then
		mycmakeargs+=(
			# Use dot to generate graphs in the doxygen documentation.
			-DCUTLASS_ENABLE_DOXYGEN_DOT="$(usex dot)"
		)
	fi

	if use test; then
		mycmakeargs+=(
			# Level of tests to compile.
			-DCUTLASS_TEST_LEVEL="2"
		)
	fi

	cmake_src_configure
}

src_test() {
	cuda_add_sandbox -w
	cmake_src_test
}

src_install() {
	cmake_src_install
	rm -r "${ED}"/usr/test || die
}
