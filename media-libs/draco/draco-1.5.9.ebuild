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
		'-*'
	)
	SLOT="0/9999"
else
	GTEST_PV="1.17.0"
	AOMEDIA_PMC_PV="18.0"
	if [[ ${PV} == *_p* ]] ; then
		COMMIT="36e7fc1f59eccaea457da369dc3d434b6700f8ec"
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
		test? (
			https://github.com/google/googletest/archive/refs/tags/v${GTEST_PV}.tar.gz
				-> gtest-${GTEST_PV}.tar.gz
		)
		transcoder? ( pmc? (
			https://gitlab.com/AOMediaVVM/reference-software/aomedia-pmc/-/archive/v${AOMEDIA_PMC_PV}/aomedia-pmc-v${AOMEDIA_PMC_PV}.tar.bz2
		) )
	"
	# from cmake/draco_build_definitions.cmake LT_CURRENT - LT_AGE
	SLOT="0/11"
	KEYWORDS="~amd64"
fi

LICENSE="Apache-2.0"

IUSE="+compat debug gltf pmc test"
IUSE+="
	transcoder
"
# IUSE+="
# 	usd
# 	javascript
# "

RDEPEND="
	transcoder? (
		dev-cpp/eigen:=
		dev-cpp/gulrak-filesystem
		<dev-cpp/tinygltf-3
	)
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

REQUIRED_USE="
	?? ( gltf transcoder )
"
DOCS=( AUTHORS CONTRIBUTING.md README.md )

PATCHES=(
	"${FILESDIR}/${PN}-1.5.7-fix-include-cstdint.patch"
	"${FILESDIR}/${PN}-9999-fix-reader-file-collision.patch"
	# "${FILESDIR}/${PN}-1.5.8-support-tinygltf-v3.patch"
)

src_unpack() {
	if [[ ${PV} =~ 9999 ]] ; then
		git-r3_fetch
		git-r3_checkout
	else
		default

		if use test; then
			rmdir "${S}/third_party/googletest" || die
			mv "${WORKDIR}/googletest-${GTEST_PV}" "${S}/third_party/googletest" || die
		fi

		if use transcoder && use pmc; then
			ln -snr "${WORKDIR}/aomedia-pmc-v${AOMEDIA_PMC_PV}" "${S}/third_party/pmc" || die
		fi
	fi
}

src_configure() {
	: "${CMAKE_BUILD_TYPE:=$(usex debug 'Debug' 'Release')}"
	local EMSCRIPTEN=
	local mycmakeargs=(
		# -DCMAKE_CXX_STANDARD=17
		# -DDRACO_BUILD_EXECUTABLES="yes"

		# -DDRACO_WASM="no" # $(usex javascript)"
		-DDRACO_GLTF_BITSTREAM="$(usex gltf)"
		# # -DDRACO_MAYA_PLUGIN="no" # default
		# -DBUILD_SHARED_LIBS="yes"
		# # -DDRACO_UNITY_PLUGIN="no" # default (FIXME?)
		# # -DBUILD_USD_PLUGIN="$(usex usd)" # default
		# -DDRACO_BACKWARDS_COMPATIBILITY="$(usex compat)"
		# currently only used for javascript/emscripten build and by default
		# set to on with C/C++ build
		-DDRACO_TRANSCODER_SUPPORTED="$(usex transcoder)"
		-DDRACO_DECODER_ATTRIBUTE_DEDUPLICATION="$(usex !gltf)"
		# -DDRACO_ATTRIBUTE_INDICES_DEDUPLICATION_SUPPORTED="$(usex transcoder)"
		# -DDRACO_ATTRIBUTE_VALUES_DEDUPLICATION_SUPPORTED="$(usex transcoder)"
		# -DENABLE_EXTRA_SPEED="no" # don't use -O3 optimization
		# # -DENABLE_EXTRA_WARNINGS="no"

		-DDRACO_TESTS="$(usex test)"
		# -DDRACO_VERBOSE="$(usex debug 3 0)"
		# # -DENABLE_WERROR="no" # default
		# # -DENABLE_WEXTRA="no" # add extra compiler warnings

		-DDRACO_PMC_SUPPORTED="$(usex pmc)"
		# -DDRACO_POINT_CLOUD_COMPRESSION="$(usex !gltf)"
		# -DDRACO_MESH_COMPRESSION="$(usex !gltf)"
		# -DDRACO_STANDARD_EDGEBREAKER="$(usex !gltf)"
		# -DDRACO_PREDICTIVE_EDGEBREAKER="$(usex !gltf)"
		# -DDRACO_BACKWARDS_COMPATIBILITY="$(usex !gltf "$(usex compat)")"
	)

	# if use emscripten; then
	# 	mycmakeargs+=(
	# 		# currently only used for javascript/emscripten build
	# 		# -DDRACO_ANIMATION_ENCODING="no" # $(usex javascript)"
	# 	)
	# fi

	# if use test; then
	# 	mycmakeargs+=(
	# 		-DDRACO_GOOGLETEST_PATH="${ESYSROOT}/usr/include"
	# 	)
	# fi

	if use transcoder; then
		mycmakeargs+=(
			-DDRACO_FILESYSTEM_PATH="${ESYSROOT}/usr/include"
			-DDRACO_EIGEN_PATH="${ESYSROOT}/usr/include/eigen3"
			-DDRACO_TINYGLTF_PATH="${ESYSROOT}/usr/include/nlohmann"
		)
	fi

	cmake_src_configure
}

src_compile() {
	if use transcoder &&  use pmc; then
		cmake_src_compile pmc_ext
	fi
	cmake_src_compile all
}

src_test() {
	cd "${BUILD_DIR}" || die
	edo "${BUILD_DIR}/draco_tests" --gtest_brief=1
	edo "${BUILD_DIR}/draco_factory_tests" --gtest_brief=1
}
