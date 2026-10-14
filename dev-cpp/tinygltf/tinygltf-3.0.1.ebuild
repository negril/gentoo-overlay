# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit cmake edo python-any-r1

DESCRIPTION="Header only C++11 tiny glTF 2.0 library"
HOMEPAGE="https://github.com/syoyo/tinygltf"

if [[ ${PV} =~ 9999 ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/syoyo/tinygltf.git"
else
	SAMPLE_MODELS="d7a3cc8e51d7c573771ae77a57f16b0662a905c6"
	SAMPLE_ASSETS="edc7c9e67c639d230715049ee31f9a96a6babbbe"
	SRC_URI="
		https://github.com/syoyo/tinygltf/archive/refs/tags/v${PV}.tar.gz
			-> ${P}.tar.gz
		"
	SRC_URI+="
		test? (
			https://github.com/KhronosGroup/glTF-Sample-Models/archive/${SAMPLE_MODELS}.tar.gz
				-> glTF-Sample-Models-${SAMPLE_MODELS}.tar.gz
		)
	"
	SRC_URI+="
		test? (
			https://github.com/KhronosGroup/glTF-Sample-Assets/archive/${SAMPLE_ASSETS}.tar.gz
				-> glTF-Sample-Assets-${SAMPLE_ASSETS}.tar.gz
		)
	"
fi

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="test"

RESTRICT="!test? ( test )"

BDEPEND="
	test? (
		${PYTHON_DEPS}
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-3.0.1-mitigate-missing-assets-count.patch"
)

pkg_setup() {
	use test && python-any-r1_pkg_setup
}

src_prepare() {
	rm -rf attic || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# Build and run tinygltf v3 C unit tests
		-DTINYGLTF3_BUILD_TESTS="$(usex test)"

		# Install tinygltf v3 files during install step
		-DTINYGLTF3_INSTALL="yes"
	)

	cmake_src_configure
}

src_test() {
	cmake_src_test

	# glTF parsing tests
	pushd "${BUILD_DIR}" >/dev/null || die
	ln -snr . tests || die

	sed -i \
		-e "/sample_model_dir =/s#\".*\"#\"${WORKDIR}/glTF-Sample-Models-${SAMPLE_MODELS}\"#" \
		"${CMAKE_USE_DIR}/test_runner.py" || die

	edo "${EPYTHON}" "${CMAKE_USE_DIR}/test_runner.py"

	sed -i \
		-e "/sample_model_dir =/s#\".*\"#\"${WORKDIR}/glTF-Sample-Assets-${SAMPLE_ASSETS}\"#" \
		-e "/base_model_dir =/s#\".*\"#\"Models\"#" \
		"${CMAKE_USE_DIR}/test_runner.py" || die

	edo "${EPYTHON}" "${CMAKE_USE_DIR}/test_runner.py"

	popd >/dev/null || die
}
