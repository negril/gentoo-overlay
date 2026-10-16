# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Notes:
# - We don't add USE flags for ccache and distcc, because the library builds
#   in minimal time (a few seconds)

EAPI=8

inherit cmake edo

DESCRIPTION="Library for compressing and decompressing 3D geometric objects"
HOMEPAGE="https://google.github.io/draco/ https://github.com/google/draco"

if [[ ${PV} =~ 9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/google/draco.git"
	EGIT_BRANCH="main"
	EGIT_SUBMODULES=(
		'*'
		'-third_party/eigen'
		'-third_party/filesystem'
	)
	SLOT="0/9999"
else
	GTEST_PV="1.17.0"
	if [[ ${PV} == *_p* ]] ; then
		COMMIT="47238930f698250f474163e1a29d77858aa5c158"
		SRC_URI="
			https://github.com/google/draco/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
		"
		S="${WORKDIR}/${PN}-${COMMIT}"
	else
		SRC_URI="
			https://github.com/google/draco/archive/${PV}.tar.gz -> ${P}.tar.gz
		"
	fi
	SRC_URI+="
		https://github.com/google/googletest/archive/refs/tags/v${GTEST_PV}.tar.gz
			-> gtest-${GTEST_PV}.tar.gz
	"
	# from cmake/draco_build_definitions.cmake LT_CURRENT - LT_AGE
	SLOT="0/9"
	KEYWORDS="~amd64"
fi

LICENSE="Apache-2.0"

IUSE="+compat debug gltf test"
IUSE+="
	transcoder
"
# 	usd
# 	javascript
# "

RDEPEND="
	dev-cpp/eigen:=
"
# RDEPEND+="
# 	usd? (
# 		media-libs/openusd
# 	)
# 	javascript? (
# 		dev-util/emscripten[llvm_targets_WebAssembly(+)]
# 	)
# "

DEPEND="${RDEPEND}
	virtual/pkgconfig
"
# Testing needs the dev-cpp/gtest source code to be available in a
# side-directory of the draco sources, therefore we restrict test for now.
RESTRICT="!test? ( test ) mirror"
DOCS=( AUTHORS CONTRIBUTING.md README.md )

PATCHES=(
	"${FILESDIR}/${PN}-1.5.7-fix-include-cstdint.patch"
	"${FILESDIR}/${PN}-9999-fix-reader-file-collision.patch"
)

src_unpack() {
	if [[ ${PV} =~ 9999 ]] ; then
		git-r3_fetch
		git-r3_checkout
	else
		default

		rmdir "${S}/third_party/googletest" || die
		mv "${WORKDIR}/googletest-${GTEST_PV}" "${S}/third_party/googletest" || die
	fi
}

src_configure() {
	: "${CMAKE_BUILD_TYPE:=$(usex debug 'Debug' 'Release')}"
	EMSCRIPTEN=
	local mycmakeargs=(
		-DCMAKE_CXX_STANDARD=17
		-DDRACO_EIGEN_PATH="${ESYSROOT}/usr/include/eigen3"
		# -DDRACO_TINYGLTF_PATH=
		# currently only used for javascript/emscripten build
		-DDRACO_ANIMATION_ENCODING="no" # $(usex javascript)"
		-DDRACO_WASM="no" # $(usex javascript)"
		-DDRACO_GLTF_BITSTREAM="$(usex gltf)"
		# -DDRACO_MAYA_PLUGIN="no" # default
		-DBUILD_SHARED_LIBS="yes"
		# -DDRACO_UNITY_PLUGIN="no" # default (FIXME?)
		# -DBUILD_USD_PLUGIN="$(usex usd)" # default
		-DDRACO_BACKWARDS_COMPATIBILITY="$(usex compat)"
		# currently only used for javascript/emscripten build and by default
		# set to on with C/C++ build
		-DDRACO_TRANSCODER_SUPPORTED="$(usex transcoder)"
		-DENABLE_DECODER_ATTRIBUTE_DEDUPLICATION="no"
		-DENABLE_EXTRA_SPEED="no" # don't use -O3 optimization
		# -DENABLE_EXTRA_WARNINGS="no"
		-DDRACO_MESH_COMPRESSION="yes" # default
		-DDRACO_POINT_CLOUD_COMPRESSION="yes" # default
		-DDRACO_PREDICTIVE_EDGEBREAKER="yes" # default
		-DDRACO_STANDARD_EDGEBREAKER="yes" # default
		-DDRACO_TESTS="$(usex test)"
		-DDRACO_VERBOSE="$(usex debug 3 0)"
		# -DENABLE_WERROR="no" # default
		# -DENABLE_WEXTRA="no" # add extra compiler warnings
	)

	cmake_src_configure
}

src_test() {
	cd "${BUILD_DIR}" || die
	edo "${BUILD_DIR}/draco_tests" --gtest_brief=1
	edo "${BUILD_DIR}/draco_factory_tests" --gtest_brief=1
}
