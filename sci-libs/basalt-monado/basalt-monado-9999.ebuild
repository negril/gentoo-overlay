# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Visual-Inertial Mapping with Non-Linear Factor Recovery (mateosss)"
HOMEPAGE="https://gitlab.freedesktop.org/mateosss/basalt"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://gitlab.freedesktop.org/mateosss/basalt.git"
	EGIT_SUBMODULES=( '-*' 'thirdparty/basalt-headers' )
else
	SRC_URI="https://gitlab.freedesktop.org/mateosss/basalt/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.bz2"
	KEYWORDS="~amd64"
fi

LICENSE="BSD"
SLOT="0"
IUSE="benchmark ros test"
RESTRICT="!test? ( test )"

RDEPEND="
	ros? (
		app-arch/lz4
	)
	dev-libs/boost
	dev-libs/libfmt
	dev-cpp/tbb
	media-libs/opencv
	dev-cpp/cli11
	dev-cpp/magic_enum
	dev-libs/libfmt
	dev-libs/cereal
	sci-libs/Sophus
"

DEPEND="
	dev-cpp/eigen:3
	${RDEPEND}
	test? (
		dev-cpp/gtest
		benchmark? (
			dev-cpp/benchmark
		)
	)
"

REQUIRED_USE="benchmark? ( test )"

PATCHES=(
	"${FILESDIR}/${P}-fix-build.patch"
  "${FILESDIR}/${P}-fix-build.2.patch"
)

# src_prepare() {
# 	cmake_src_prepare
# 	cp "${FILESDIR}/dump_cmake_variables.cmake" . || die
#
# 	# NOTE Append some useful summary here
# 	cat >> CMakeLists.txt <<- _EOF_ || die
# 		message("CMAKE_COLOR_DIAGNOSTICS: ${CMAKE_COLOR_DIAGNOSTICS}")
# 		set(CMAKE_MODULE_PATH "\${CMAKE_SOURCE_DIR}")
# 		message(STATUS "<<< Targets >>>\n")
# 		include(dump_cmake_variables)
#
# 		get_property(target_names DIRECTORY \${CMAKE_CURRENT_SOURCE_DIR} PROPERTY BUILDSYSTEM_TARGETS)
# 		# message("target_names \${target_names}")
#
# 		# Run at end of top-level CMakeLists
# 		_get_all_cmake_targets(all_targets \${CMAKE_CURRENT_LIST_DIR})
# 		message(STATUS "all_targets")
# 		foreach(target IN LISTS all_targets)
# 		    message(STATUS "  \${target}")
# 		endforeach()
#
# 		print_target_properties(Eigen3::Eigen)
# 	_EOF_
# }

src_configure() {
	local mycmakeargs=(
		-DCUSTOM_FLAGS=ON
		-DEIGEN_ROOT="$(pkg-config eigen3 --cflags-only-I | cut -c3-)"

		# Build against ROS
		-DBUILD_ROS="$(usex ros ON OFF)"
		# Build Tests
		-DBUILD_TESTS="$(usex test ON OFF)"
		# Build only Basalt shared library
		-DBASALT_BUILD_SHARED_LIBRARY_ONLY="OFF"
		# Use builtin CLI11 from submodule
		-DBASALT_BUILTIN_CLI11="OFF"
		# Use builtin magic_enum from submodule
		-DBASALT_BUILTIN_MAGIC_ENUM="OFF"
		# Use builtin opengv from submodule
		-DBASALT_BUILTIN_OPENGV="OFF"
		# Use builtin Pangolin from submodule
		-DBASALT_BUILTIN_PANGOLIN="OFF"
		# Instantiate templates for Scalar=double
		-DBASALT_INSTANTIATIONS_DOUBLE="ON"
		# Instantiate templates for Scalar=float.
		-DBASALT_INSTANTIATIONS_FLOAT="ON"

		# Use builtin Cereal from submodule
		-DBASALT_BUILTIN_CEREAL="OFF"
		# Use builtin Eigen from submodule
		-DBASALT_BUILTIN_EIGEN="OFF"
		# Use builtin Sophus from submodule
		-DBASALT_BUILTIN_SOPHUS="OFF"
	)
	if use test; then
		mycmakeargs+=(
			# Use builtin GoogleTest from submodule
			-DBASALT_BUILTIN_GTEST="OFF"
		)
		if use benchmark; then
			mycmakeargs+=(
				# Use builtin benchmark from submodule
				-DBASALT_BUILTIN_BENCHMARK="OFF"
				# Build camera benchmark
				-DBUILD_BENCHMARK="$(usex benchmark ON OFF)"
			)
		fi
	fi
	cmake_src_configure
}

src_test() {
	cmake_src_test
	use benchmark && "${BUILD_DIR}/thirdparty/basalt-headers/test/benchmark_camera"
}
