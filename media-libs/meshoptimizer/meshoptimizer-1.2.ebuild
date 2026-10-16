# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Mesh optimization library that makes meshes smaller and faster to render"
HOMEPAGE="https://github.com/zeux/meshoptimizer"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/zeux/meshoptimizer.git"
else
	SRC_URI="
		https://github.com/zeux/meshoptimizer/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"

IUSE="test"
RESTRICT="!test? ( test )"

src_configure() {
	local mycmakeargs=(
		-DMESHOPT_BUILD_SHARED_LIBS="yes"
		-DMESHOPT_BUILD_GLTFPACK="no"
		-DMESHOPT_BUILD_DEMO="$(usex test)"
	)

	cmake_src_configure
}
