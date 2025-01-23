# Copyright 2023-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
inherit cmake python-r1

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

IUSE="+examples +python test"

RDEPEND="
	python? (
		dev-libs/libfmt
		${PYTHON_DEPS}
		$(python_gen_any_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
"

DEPEND="
	dev-cpp/eigen
	${RDEPEND}
	test? (
		>=sci-libs/ceres-solver-2
	)
"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
"
RESTRICT="!test? ( test )"

PATCHES=(
	"${FILESDIR}/${PN}-1.24.6-use-system-pybind11.patch"
)

src_configure() {
	local mycmakeargs=(
		-DBUILD_PYTHON_BINDINGS="$(usex python)"
		-DBUILD_SOPHUS_TESTS="$(usex test)"

		-DSOPHUS_INSTALL="yes"
	)

	if use python; then
		sophus_configure() {
			local mycmakeargs=(
				"${mycmakeargs[@]}"
				-DPython_EXECUTABLE="${PYTHON}"
			)
			cmake_src_configure
		}

		python_foreach_impl sophus_configure
	else
		cmake_src_configure
	fi
}

src_compile() {
	if use python; then
		python_foreach_impl cmake_src_compile
	else
		cmake_src_compile
	fi
}

src_test() {
	local CMAKE_SKIP_TESTS=(
		"^test_sim3$"
	)

	if use python; then
		python_foreach_impl cmake_src_test
	else
		cmake_src_test
	fi
}

src_install() {
	if use python; then
		sophus_install() {
			if [[ $(${PYTHON} -V) == $(python -V) ]]; then
				cmake_src_install
			fi
			einfo python_domodule "${BUILD_DIR}"/sophus_pybind.cpython-*.so
			python_domodule "${BUILD_DIR}"/sophus_pybind.cpython-*.so
		}
		python_foreach_impl sophus_install
	else
		cmake_src_install
	fi
}
