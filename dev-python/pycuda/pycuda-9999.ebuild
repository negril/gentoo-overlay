# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
DISTUTILS_EXT=1
PYTHON_COMPAT=( python3_{10..13} )
inherit cuda distutils-r1

DESCRIPTION="Python wrapper for NVIDIA CUDA"
HOMEPAGE="
	https://mathema.tician.de/software/pycuda/
	https://pypi.org/project/pycuda/
	https://github.com/inducer/pycuda
"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/inducer/pycuda.git"
	EGIT_SUBMODULES=(
		'-*'
		'pycuda/compyte'
	)
else
	inherit pypi
	KEYWORDS="~amd64"
fi

LICENSE="Apache-2.0 MIT"
SLOT="0"
IUSE="examples opengl test"

# TODO qa-vdb says boost should not be in RDEPEND
RDEPEND="
	dev-libs/boost:=[python,${PYTHON_USEDEP}]
	dev-python/appdirs[${PYTHON_USEDEP}]
	dev-python/decorator[${PYTHON_USEDEP}]
	dev-python/mako[${PYTHON_USEDEP}]
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/pytools[${PYTHON_USEDEP}]
	dev-util/nvidia-cuda-toolkit:=[profiler]
	x11-drivers/nvidia-drivers
	opengl? ( virtual/opengl )
"
DEPEND="${RDEPEND}"

# We need write acccess /dev/nvidia0 and /dev/nvidiactl and the portage user is (usually) not in the video group
PROPERTIES="test_privileged"
RESTRICT="!test? ( test )" # test"

PATCHES=(
	# "${FILESDIR}/${PN}-2025.1.1-python-cleanup.patch"
)

EPYTEST_PLUGINS=(
)

distutils_enable_tests pytest

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_src_unpack

		git -C "${S}" submodule update --init
	else
		default
		rm -r "${S}/bpl-subset/"* || die
	fi
}

src_prepare() {
	cuda_sanitize

	# This hard codes the compiler version...
	# We need to strip the '"' from cuda_gccdir
	sed "s|\"--preprocess\"|&,\"--compiler-bindir=$(cuda_gccdir | sed 's/"//g')\"|" \
		-i pycuda/compiler.py || die

# 	> siteconf.py || die

	distutils-r1_src_prepare
}

python_configure() {
	mkdir -p "${BUILD_DIR}" || die
	cd "${BUILD_DIR}" || die

	local CXXFLAGS_a LDFLAGS_a
	read -ra CXXFLAGS_a <<<"${CXXFLAGS}"
	read -ra LDFLAGS_a <<<"${LDFLAGS}"

	local conf=(
		"${EPYTHON}" "${S}"/configure.py
		--python-exe="${EPYTHON}"
		--no-use-shipped-boost
		--boost-inc-dir="${ESYSROOT}"/usr/include
		--boost-lib-dir="${ESYSROOT}"/usr/$(get_libdir)
		--boost-python-libname=boost_${EPYTHON/./}
		--boost-thread-libname=boost_thread
		--cuda-inc-dir=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}/include
		--cuda-root=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}
		--cudadrv-lib-dir="${ESYSROOT}"/usr/$(get_libdir)
		--cudart-lib-dir=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}/$(get_libdir)
		# --no-cuda-enable-curand
		$(usex opengl --cuda-enable-gl "")
		$(printf -- '--cxxflags=%q\n' "${CXXFLAGS_a[@]}")
		$(printf -- '--ldflags=%q\n' "${LDFLAGS_a[@]}")
		--cxxflags="-Wno-deprecated-declarations"
	)
	einfo "${conf[@]}"
	"${conf[@]}" || die
}

python_test() {
	T="${T%/}"
	# we need write access to this to run the tests
	cuda_add_sandbox -w

	EPYTEST_IGNORE=(
		# "../work/${P}/test/test_cumath.py"
		# "../work/${P}/test/test_driver.py"
		# "../work/${P}/test/test_gpuarray.py"
		# "../work/${P}/test/undistributed/elwise-perf.py"
		# "../work/${P}/test/undistributed/measure_gpuarray_speed.py"
		# "../work/${P}/test/undistributed/reduction-perf.py"
	)

	EPYTEST_DESELECT=(
		# # needs investigation, perhaps failure is hardware-specific
		# test/test_driver.py::test_pass_cai_array
		# test/test_driver.py::test_pointer_holder_base
		"test/test_driver.py::TestDriver::test_2d_texture"
		"test/test_driver.py::TestDriver::test_multiple_2d_textures"
		"test/test_driver.py::TestDriver::test_multichannel_2d_texture"
		"test/test_driver.py::TestDriver::test_multichannel_linear_texture"
		"test/test_driver.py::TestDriver::test_2d_fp_textures"
		"test/test_driver.py::TestDriver::test_2d_fp_textures_layered"
		"test/test_driver.py::TestDriver::test_3d_fp_textures"
		"test/test_driver.py::TestDriver::test_3d_fp_surfaces"
		"test/test_driver.py::TestDriver::test_2d_fp_surfaces"
		"test/test_driver.py::TestDriver::test_3d_texture"
		"test/test_driver.py::TestDriver::test_fp_textures"
		"test/test_driver.py::TestDriver::test_register_host_memory"
		# Need at least 9.0 GB memory
		"test/test_gpuarray.py::TestGPUArray::test_curand_wrappers_8gb"
		# Need at least 17.0 GB memory
		"test/test_gpuarray.py::TestGPUArray::test_curand_wrappers_16gb"
		# texture references were removed in CUDA 12
		"test/test_gpuarray.py::TestGPUArray::test_take"
		"test/test_gpuarray.py::TestGPUArray::test_take_put"
		# https://github.com/inducer/pycuda/issues/163
		"test/test_gpuarray.py::TestGPUArray::test_sum_allocator"
		"test/test_gpuarray.py::TestGPUArray::test_dot_allocator"
		# Enable after gitlab.tiker.net/inducer/pycuda/-/merge_requests/66 is merged
		"test/test_gpuarray.py::TestGPUArray::test_binary_ops_with_unequal_dtypes[truediv-int32-int32]"
		"test/test_gpuarray.py::TestGPUArray::test_binary_ops_with_unequal_dtypes[truediv-int32-int64]"
		"test/test_gpuarray.py::TestGPUArray::test_binary_ops_with_unequal_dtypes[truediv-int64-int32]"
		"test/test_gpuarray.py::TestGPUArray::test_binary_ops_with_unequal_dtypes[truediv-int64-int64]"
		# Need at least 4.5 GB memory
		"test/test_gpuarray.py::TestGPUArray::test_big_array_elementwise"
		"test/test_gpuarray.py::TestGPUArray::test_big_array_reduction"
		"test/test_gpuarray.py::TestGPUArray::test_big_array_scan"
	)

	local -x NVCC_CCBIN="$(cuda_gccdir)"
# 	local -x NVCC_CCBIN="g++-14"
# 	local -x NVCC_APPEND_FLAGS="-arch=sm_89"
# 	local -x NVCC_APPEND_FLAGS="--compiler-bindir=/usr/x86_64-pc-linux-gnu/gcc-bin/15"
# 	local -x PYCUDA_DEFAULT_NVCC_FLAGS="--compiler-bindir=/usr/lib/ccache/bin/x86_64-pc-linux-gnu-g++-15" # -Ofc max
	# set this to avoid failing relative path lookup when using ccache
	eqawarn "CUDA_PATH ${CUDA_PATH}"
	local -x CUDA_ROOT="${CUDA_PATH:-/opt/cuda}"
	eqawarn "CUDA_ROOT ${CUDA_ROOT}"
	eqawarn "NVCC_CCBIN ${NVCC_CCBIN}"

	eqawarn "NVCCFLAGS ${NVCCFLAGS}"
	eqawarn "NVCC_PREPEND_FLAGS ${NVCC_PREPEND_FLAGS}"
	eqawarn "NVCC_APPEND_FLAGS ${NVCC_APPEND_FLAGS}"

	env | rg -iP '^(NVCC|CUDA)' | sort

	cd "${T}" || die
	epytest "${S}"/test
}

python_install_all() {
	distutils-r1_python_install_all

	if use examples; then
		dodoc -r examples
		docompress -x "/usr/share/doc/${PF}/examples"
	fi
}
