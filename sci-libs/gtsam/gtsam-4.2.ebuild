# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
inherit cmake flag-o-matic python-r1
#   optfeature virtualx xdg

DESCRIPTION="Factor graphs for Sensor Fusion in Robotics"
HOMEPAGE="https://gtsam.org/"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/borglab/gtsam.git"
	EGIT_SUBMODULES=(
		'-*'
	)
else
	SRC_URI="
		https://github.com/borglab/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="BSD"
SLOT="0"

IUSE="asan debug doc examples gperf html latex metis mkl python +quaternion +tbb test"
RESTRICT="!test? ( test )"

REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

RDEPEND="
	dev-libs/boost:=
	sci-geosciences/GeographicLib
	mkl? ( sci-libs/mkl )
	python? (
		$(python_gen_cond_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
"
DEPEND="${RDEPEND}
	dev-cpp/eigen:=
"

PATCHES=(
	"${FILESDIR}/${PN}-4.2-include-bitset.patch"
)

python_check_deps() {
	python_has_version "dev-python/pybind11[${PYTHON_USEDEP}]"
}

# pkg_setup() {
# 	use test && python-r1_pkg_setup
# }

src_prepare() {
	cmake_src_prepare

	sed -re "/cmake_minimum_required/s/(VERSION) [\.0-9]*/\1 3.10/" \
		-i \
			CMakeLists.txt \
			wrap/CMakeLists.txt \
		|| die

	sed -e "s/-O3 //g" -i cmake/GtsamBuildTypes.cmake || die

	sed -re "/find_package\(Boost/s/Boost/Boost CONFIG/" \
		-i cmake/HandleBoost.cmake || die

	rm -R gtsam/3rdparty/{Eigen,GeographicLib}/ || die

	sed -e "/FindGeographicLib/s/.*/find_package(GeographicLib)/" \
		-i gtsam/3rdparty/CMakeLists.txt || die

}

src_configure() {
	filter-lto

	local mycmakeargs=(
		# add debugging support
		-DDEBUG="$(usex debug)"

		# Allow use of methods/functions deprecated in GTSAM 4.2
		-DGTSAM_ALLOW_DEPRECATED_SINCE_V42="yes"

		# Enable/Disable building of doxygen docs
		-DGTSAM_BUILD_DOCS="$(usex doc)"

		# Enable/Disable doxygen HTML output
		-DGTSAM_BUILD_DOC_HTML="$(usex doc "$(usex html)")"

		# Enable/Disable doxygen LaTeX output
		-DGTSAM_BUILD_DOC_LATEX="$(usex doc "$(usex latex)")"

		# Build examples with 'make all' (build with 'make examples' if not)
		-DGTSAM_BUILD_EXAMPLES_ALWAYS="no"

		# Enable/Disable building & installation of Python module with pybind11
		-DGTSAM_BUILD_PYTHON="$(usex python)"

		# Enable/Disable building of tests
		-DGTSAM_BUILD_TESTS="$(usex test)"

		# Build timing scripts with 'make all' (build with 'make timing' if not
		-DGTSAM_BUILD_TIMING_ALWAYS="no"

		# Enable/Disable appending the build type to the name of compiled libraries
		-DGTSAM_BUILD_TYPE_POSTFIXES="yes"

		# Enable/Disable libgtsam_unstable
		-DGTSAM_BUILD_UNSTABLE="no"

		# Use ccache compiler cache
		-DGTSAM_BUILD_WITH_CCACHE="no"

		# Disables using Boost.chrono for timing
		-DGTSAM_DISABLE_NEW_TIMERS="no"

		# Enable/Disable expensive consistency checks
		-DGTSAM_ENABLE_CONSISTENCY_CHECKS="no"

		# Enable/Disable installation of CppUnitLite library
		-DGTSAM_INSTALL_CPPUNITLITE="no"

		# Build and install the 3rd-party library GeographicLib
		-DGTSAM_INSTALL_GEOGRAPHICLIB="no"

		# Enable/Disable installation of matlab toolbox
		-DGTSAM_INSTALL_MATLAB_TOOLBOX="no"

		# Enable/Disable using Pose3::EXPMAP as the default mode. If disabled, Pose3::FIRST_ORDER will be used.
		-DGTSAM_POSE3_EXPMAP="yes"

		# #
		# -DGTSAM_ROT3_EXPMAP=yes

		# #
		# -DGTSAM_SHARED_LIB=1

		# Use the slower but correct version of BetweenFactor
		-DGTSAM_SLOW_BUT_CORRECT_BETWEENFACTOR="no"

		# Support Metis-based nested dissection
		-DGTSAM_SUPPORT_NESTED_DISSECTION="yes"

		# Use new ImuFactor with integration on tangent space
		-DGTSAM_TANGENT_PREINTEGRATION="yes"

		# Throw exception when a triangulated point is behind a camera
		-DGTSAM_THROW_CHEIRALITY_EXCEPTION="yes"

		# Enable/Disable Python wrapper for libgtsam_unstable
		-DGTSAM_UNSTABLE_BUILD_PYTHON="$(usex python no)"

		# Enable/Disable MATLAB wrapper for libgtsam_unstable
		-DGTSAM_UNSTABLE_INSTALL_MATLAB_TOOLBOX="no"

		# Enable/Disable using an internal Quaternion representation for rotations instead of rotation matrices.
		# If enable, Rot3::EXPMAP is enforced by default.
		-DGTSAM_USE_QUATERNIONS="$(usex quaternion)"

		# Find and use system-installed Eigen. If 'off', use the one bundled with GTSAM
		-DGTSAM_USE_SYSTEM_EIGEN="yes"

		# Find and use system-installed libmetis. If 'off', use the one bundled with GTSAM
		-DGTSAM_USE_SYSTEM_METIS="yes"

		# Eigen will use Intel MKL if available
		-DGTSAM_WITH_EIGEN_MKL="$(usex mkl)"

		# Eigen, when using Intel MKL, will also use OpenMP for multithreading if available
		-DGTSAM_WITH_EIGEN_MKL_OPENMP="$(usex openmp)"

		# Use Intel Threaded Building Blocks (TBB) if available
		-DGTSAM_WITH_TBB="$(usex tbb)"
	)
	use python && mycmakeargs+=(
		-DPYBIND11_FINDPYTHON="yes"
	)

	cmake_src_configure
}

src_compile() {
	local mycmaketargets=()

	use python && mycmaketargets+=( gtsam_py )
	use test && mycmaketargets+=( all.tests )

	cmake_src_compile "${mycmaketargets[@]}"
}
