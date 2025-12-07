# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=scikit-build-core

inherit distutils-r1 multiprocessing pypi cuda

DESCRIPTION="Python wrapper for OpenCL"
HOMEPAGE="
	https://mathema.tician.de/software/pyopencl/
	https://pypi.org/project/pyopencl/
"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ppc64 ~riscv"
IUSE="cuda examples opengl pocl"

# Running tests on GPUs requires both appropriate hardware and additional permissions
# having been granted to the user running them. Testing on CPUs with dev-libs/pocl
# is in theory possible but has been found to be very fragile, see e.g. Bug #872308.
PROPERTIES="test_privileged"
# RESTRICT="test"
# RESTRICT="!test? ( test ) test"
RESTRICT="!test? ( test )"

COMMON=">=virtual/opencl-2"
# libglvnd is only needed for the headers
DEPEND="
	${COMMON}
	opengl? ( media-libs/libglvnd[X] )
"
RDEPEND="
	${COMMON}
	>=dev-python/mako-0.3.6[${PYTHON_USEDEP}]
	dev-python/numpy[${PYTHON_USEDEP}]
	>=dev-python/platformdirs-2.2.0[${PYTHON_USEDEP}]
	>=dev-python/pytools-2024.1.5[${PYTHON_USEDEP}]
"
BDEPEND="
	dev-python/numpy[${PYTHON_USEDEP}]
	dev-python/nanobind[${PYTHON_USEDEP}]
	test? ( pocl? ( dev-libs/pocl ) )
"

PATCHES=(
	"${FILESDIR}"/pyopencl-2025.1-nanobind-flags.patch
)

EPYTEST_PLUGINS=(
)

distutils_enable_tests pytest

src_prepare() {
# 	use cuda && cuda_src_prepare
	default
}

python_configure_all() {
	DISTUTILS_ARGS=(
		-DPYOPENCL_ENABLE_GL=$(usex opengl)
	)
}

python_test() {
	local -x PYOPENCL_COMPILER_OUTPUT=1
	if use cuda; then
		cuda_add_sandbox -w
		addpredict /dev/char
	fi

	if use pocl ; then
		# Use dev-libs/pocl for testing; ignore any other OpenCL devices that might be present
		local -x PYOPENCL_TEST="portable:cpu"
		# Set the number of threads to match MAKEOPTS
		local -x POCL_MAX_PTHREAD_COUNT=$(makeopts_jobs)
	fi

	EPYTEST_DESELECT=(
		# AttributeError: 'pyopencl._cl.Image' object has no attribute 'image'
		'test/test_wrapper.py::test_get_info'
	)

	# Change to the 'test' directory so that python does not try to import pyopencl from the source directory
	# (Importing from the source directory fails, because the compiled '_cl' module is only in the build directory)
	pushd test >/dev/null || die
	epytest
	popd >/dev/null || die
}

python_install_all() {
	if use examples; then
		dodoc -r examples
		docompress -x "/usr/share/doc/${PF}/examples"
	fi

	distutils-r1_python_install_all
}
