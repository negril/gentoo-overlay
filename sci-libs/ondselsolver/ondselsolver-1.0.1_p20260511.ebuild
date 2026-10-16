# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Assembly Constraints and Multibody Dynamics code"
HOMEPAGE="https://github.com/FreeCAD/OndselSolve"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/FreeCAD/OndselSolver.git"
else
	COMMIT="81867f23220157b856f9aba221e2c2be25c6f5ed"
	SRC_URI="
		https://github.com/FreeCAD/OndselSolver/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
	"
	S="${WORKDIR}/OndselSolver-${COMMIT}"
	KEYWORDS="~amd64"
fi

LICENSE="LGPL-2.1"
SLOT="0"

IUSE="test tools"
RESTRICT="!test? ( test )"

DEPEND="test? ( dev-cpp/gtest )"

PATCHES=(
	"${FILESDIR}/${PN}-1.0.1-properly-demangle-typenames.patch"
)

src_configure() {
	local mycmakeargs=(
		-DONDSELSOLVER_BUILD_EXE="$(usex tools)"
		-DONDSELSOLVER_BUILD_TESTS="$(usex test)"
	)

	cmake_src_configure
}

src_test() {
	local CMAKE_SKIP_TESTS=(
		"^OndselSolver.runPreDragBackhoe[1-3]$"
	)

	cmake_src_test
}
