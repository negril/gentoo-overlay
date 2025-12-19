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
	"${FILESDIR}/${PN}-2025.1.1-python-cleanup.patch"
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
		# rm -r "${S}/bpl-subset/"* || die
	fi
}

src_prepare() {
	cuda_sanitize

	# This hard codes the compiler version...
	# We need to strip the '"' from cuda_gccdir
	sed "s|\"--preprocess\"|&,\"--compiler-bindir=$(cuda_gccdir | sed 's/"//g')\"|" \
		-i pycuda/compiler.py || die

	> siteconf.py || die

	distutils-r1_src_prepare
}

python_configure() {
	mkdir -p "${BUILD_DIR}" || die
	cd "${BUILD_DIR}" || die

	local conf=(
		"${EPYTHON}" "${S}"/configure.py
		--boost-inc-dir="${ESYSROOT}"/usr/include
		--boost-lib-dir="${ESYSROOT}"/usr/$(get_libdir)
		--boost-python-libname=boost_${EPYTHON/./}.so
		--boost-thread-libname=boost_thread
		--cuda-inc-dir=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}/include
		--cuda-root=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}
		--cudadrv-lib-dir="${ESYSROOT}"/usr/$(get_libdir)
		--cudart-lib-dir=${CUDA_PATH:-"${ESYSROOT}"/opt/cuda}/$(get_libdir)
	)
	einfo "${conf[@]}"
	"${conf[@]}" || die
}

python_test() {
	# we need write access to this to run the tests
	cuda_add_sandbox -w

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

	local -x NVCC_CCBIN="${NVCC_CCBIN:-$(cuda_gccdir)}"
	# set this to avoid failing relative path lookup when using ccache
	local -x CUDA_ROOT="${CUDA_PATH:-/opt/cuda}"

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
