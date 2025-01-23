# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="C++ implementation of Lie Groups using Eigen."
HOMEPAGE="https://github.com/strasdat/Sophus"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/strasdat/Sophus.git"
	if [[ ${PV} == 2.9999* ]]; then
		EGIT_BRANCH="sophus2"
	fi
	EGIT_SUBMODULES=(
		'-*'
	)
else
	SRC_URI="	https://github.com/strasdat/Sophus/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0/$(ver_cut 1)"

IUSE="examples +fmt test"

RDEPEND="
	fmt? ( dev-libs/libfmt )
"

DEPEND="
	dev-cpp/eigen
	fmt? ( dev-libs/libfmt )
	test? (
		sci-libs/ceres-solver
	)
"

RESTRICT="!test? ( test )"

PATCHES=(
	"${FILESDIR}/${PN}-1.22.10-cmake-fix-build-flags.patch"
)

src_configure() {
	local mycmakeargs=(
		-DBUILD_SOPHUS_EXAMPLES="$(usex examples)"
		-DBUILD_SOPHUS_TESTS="$(usex test)"

		-DSOPHUS_USE_BASIC_LOGGING="$(usex !fmt)"
		-DSOPHUS_INSTALL="yes"
	)

	cmake_src_configure
}

src_test() {
	local CMAKE_SKIP_TESTS=(
		"^test_sim3$"
	)

	cmake_src_test
}
