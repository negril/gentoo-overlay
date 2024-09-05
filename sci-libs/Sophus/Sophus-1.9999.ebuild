# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
inherit cmake python-r1

DESCRIPTION="C++ implementation of Lie Groups using Eigen."
HOMEPAGE="https://github.com/strasdat/Sophus"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/strasdat/Sophus.git"
	EGIT_BRANCH="main-1.x"
	EGIT_SUBMODULES=(
		'-*'
	)
else
	SRC_URI="	https://github.com/strasdat/Sophus/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0/1"

IUSE="examples +fmt +python test"

RDEPEND="
	fmt? ( dev-libs/libfmt )
	python? (
		${PYTHON_DEPS}
	)
"

DEPEND="
	dev-cpp/eigen
	fmt? ( dev-libs/libfmt )
	python? (
		$(python_gen_any_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
	test? (
		sci-libs/ceres-solver
	)
"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
"
RESTRICT="!test? ( test )"

PATCHES=(
	"${FILESDIR}/${PN}-9999-cmake-fix-build-flags.patch"
	"${FILESDIR}/${PN}-9999-use-system-pybind11.patch"
)

src_configure() {
	local mycmakeargs=(
		-DBUILD_PYTHON_BINDINGS="$(usex python)"
		-DBUILD_SOPHUS_EXAMPLES="$(usex examples)"
		-DBUILD_SOPHUS_TESTS="$(usex test)"

		-DSOPHUS_USE_BASIC_LOGGING="$(usex !fmt)"
		-DSOPHUS_INSTALL="ON"
	)

	if use python; then
		pangolin_configure() {
			local mycmakeargs=(
				"${mycmakeargs[@]}"
				-DPython_EXECUTABLE="${PYTHON}"
			)
			cmake_src_configure
		}

		python_foreach_impl pangolin_configure
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
			python_domodule "${BUILD_DIR}"/sophus_pybind.cpython-*.so
		}
		python_foreach_impl sophus_install
	else
		cmake_src_install
	fi
}
