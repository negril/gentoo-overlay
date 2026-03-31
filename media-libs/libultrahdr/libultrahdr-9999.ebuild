# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake edo flag-o-matic

DESCRIPTION="Ultra HDR is a true HDR image format"
HOMEPAGE="https://github.com/google/libultrahdr"

BENCHMARK_PV="1.2"
if [[ ${PV} == *9999* ]] ; then
	EGIT_REPO_URI="https://github.com/google/libultrahdr.git"
	inherit git-r3
else
	SRC_URI="
		https://github.com/google/libultrahdr/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64"
fi

SRC_URI+="
	benchmark? (
		https://storage.googleapis.com/android_media/external/libultrahdr/benchmark/UltrahdrBenchmarkTestRes-${BENCHMARK_PV}.zip
			-> UltrahdrBenchmarkTestRes-${BENCHMARK_PV}.zip.raw
	)
"

LICENSE="Apache-2.0"
SLOT="0/$(ver_cut 1)"
IUSE="benchmark debug egl tools test"
RESTRICT="!test? ( test )"

RDEPEND="
	media-libs/libjpeg-turbo:=
	egl? (
		media-libs/libglvnd
	)
"

DEPEND="${RDEPEND}
	test? (
		>=dev-cpp/gtest-1.14.0
		benchmark? (
			>=dev-cpp/benchmark-1.8.3
		)
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-1.4.0-use-FetchContent.patch"
	"${FILESDIR}/${PN}-9999-static-libs-optional.patch"
)

src_prepare() {
	cmake_src_prepare

	if use benchmark; then
		ln -s \
			"${DISTDIR}/UltrahdrBenchmarkTestRes-${BENCHMARK_PV}.zip.raw" \
			"${S}/tests/data/UltrahdrBenchmarkTestRes-${BENCHMARK_PV}.zip" \
		|| die
	fi
}

src_configure() {
	# TODO stripped in cmake.eclass fix
	append-cxxflags "$(usex debug '-DDEBUG' '-DNDEBUG')"

	local mycmakeargs=(
		-DBUILD_SHARED_LIBS="yes"

		-DUHDR_BUILD_BENCHMARK="$(usex benchmark)"
		-DUHDR_BUILD_DEPS="no"
		-DUHDR_BUILD_EXAMPLES="$(usex tools)"
		-DUHDR_BUILD_FUZZERS="no"
		-DUHDR_BUILD_JAVA="no"
		-DUHDR_BUILD_PACKAGING="no"
		-DUHDR_BUILD_TESTS="$(usex test)"
		-DUHDR_ENABLE_GLES="$(usex egl)"
		-DUHDR_ENABLE_INSTALL="yes"
		-DUHDR_ENABLE_INTRINSICS="yes" # arm neon specific
		-DUHDR_ENABLE_LOGS="$(usex debug)"
		-DUHDR_ENABLE_WERROR="no"
		-DUHDR_WRITE_ISO="yes"
		-DUHDR_WRITE_XMP="yes"
	)

	cmake_src_configure
}

src_test() {
	cmake_src_test

	if use benchmark; then
		cd "${BUILD_DIR}" || die
		edo "./ultrahdr_bm"
	fi
}
