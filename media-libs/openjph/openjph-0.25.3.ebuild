# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="OpenJPH"

inherit cmake-multilib flag-o-matic

DESCRIPTION="Open source implementation of JPH (high-throughput JPEG2000) library"
HOMEPAGE="https://github.com/aous72/OpenJPH"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/aous72/${PN}.git"
	TEST_REPO_URI="https://github.com/aous72/jp2k_test_codestreams.git"
else
	TEST_COMMIT="eda0844b9f3be47d9b64194bcea5eb1ac2285e39"
	SRC_URI="
		https://github.com/aous72/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
		test? (
			https://github.com/aous72/jp2k_test_codestreams/archive/${TEST_COMMIT}.tar.gz -> ${PN}-jp2k_test_codestreams-${TEST_COMMIT:0:8}.tar.gz
		)
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="BSD-2"
SLOT="0/$(ver_cut 1-2)" # based on SONAME
IUSE="doc test tiff +tools"

declare -A CPU_FEATURES=(
	[AVX]="x86"
	[AVX2]="x86"
	[AVX512F]="x86"
	[NEON]="arm"
	[SSE]="x86"
	[SSE2]="x86"
	[SSE4_1]="x86"
	[SSSE3]="x86"
)

add_cpu_features_use() {
	for flag in "${!CPU_FEATURES[@]}"; do
		IFS=$';' read -r arch use <<< "${CPU_FEATURES[${flag}]}"
		IUSE+=" cpu_flags_${arch}_${use:-${flag,,}}"
	done
}
add_cpu_features_use

RESTRICT="!test? ( test )"
REQUIRED_USE="test? ( tools )"
RDEPEND="
	tiff? (
		media-libs/tiff:=[${MULTILIB_USEDEP}]
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	doc? (
		app-text/doxygen
	)
	test? (
		dev-cpp/gtest[${MULTILIB_USEDEP}]
	)
"

DOCS=(
	README.md
)

PATCHES=(
	"${FILESDIR}/${PN}-0.25.3-system-gtest.patch"
	"${FILESDIR}/${PN}-0.25.3-use-prefetched-test-data.patch"
	"${FILESDIR}/${PN}-0.25.3-fix-ub.patch"
	"${FILESDIR}/${PN}-0.25.3-Warray-bounds.patch"
)

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_fetch
		git-r3_checkout

		if use test; then
			git-r3_fetch "${TEST_REPO_URI}"
			git-r3_checkout "${TEST_REPO_URI}" "${WORKDIR}/jp2k_test_codestreams-${PV}"

			ln -srvf "${WORKDIR}/jp2k_test_codestreams-${PV}" "${S}/tests/jp2k_test_codestreams" || die
		fi
	else
		default

		if use test; then
			mv "${WORKDIR}/jp2k_test_codestreams-${TEST_COMMIT}" "${S}/tests/jp2k_test_codestreams" || \
				die "Failed to rename test data"
		fi
	fi
}

multilib_src_configure() {
	# https://github.com/aous72/OpenJPH/issues/186
	# append-flags -fno-strict-aliasing
	# append-cxxflags -fno-lifetime-dse

	local mycmakeargs=(
		# defaults to 11
		-DCMAKE_C_STANDARD=23
		# defaults to 14
		-DCMAKE_CXX_STANDARD=20

		-DOJPH_BUILD_EXECUTABLES="$(usex tools)"
		-DOJPH_BUILD_STREAM_EXPAND="$(usex tools)"
		-DOJPH_ENABLE_TIFF_SUPPORT="$(usex tiff)"

		-DOJPH_DISABLE_AVX2="$(usex !cpu_flags_x86_avx2)"
		-DOJPH_DISABLE_AVX512="$(usex !cpu_flags_x86_avx512f)"
		-DOJPH_DISABLE_AVX="$(usex !cpu_flags_x86_avx)"
		-DOJPH_DISABLE_NEON="$(usex !cpu_flags_arm_neon)"
		-DOJPH_DISABLE_SIMD="no"
		-DOJPH_DISABLE_SSE2="$(usex !cpu_flags_x86_sse2)"
		-DOJPH_DISABLE_SSE4="$(usex !cpu_flags_x86_sse4_1)"
		-DOJPH_DISABLE_SSE="$(usex !cpu_flags_x86_sse)"
		-DOJPH_DISABLE_SSSE3="$(usex !cpu_flags_x86_ssse3)"

		-DOJPH_BUILD_TESTS="$(usex test)"
	)

	cmake_src_configure
}

multilib_src_test() {
	ln -srvf "${S}/tests/jp2k_test_codestreams" "${BUILD_DIR}/tests/jp2k_test_codestreams" || die

	cmake_src_test
}

multilib_src_install() {
	cmake_src_install
}

multilib_src_install_all() {
	if use doc; then
		doxygen "${S}/docs" || die
		dodoc -r html
	fi
}
