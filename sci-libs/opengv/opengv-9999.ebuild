# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
inherit cmake python-r1

DESCRIPTION="A collection of computer vision methods for solving geometric vision problems."
HOMEPAGE="https://github.com/laurentkneip/opengv"

if [[ ${PV} == 9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/laurentkneip/opengv.git"
	EGIT_SUBMODULES=(
		'-*'
	)
fi

LICENSE="MIT"
SLOT="0"

IUSE="python +shared test"

DEPEND="
	dev-cpp/eigen
	${RDEPEND}
	python? (
		$(python_gen_any_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
"

RDEPEND+="
	python? (
		${PYTHON_DEPS}
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
		-DBUILD_PYTHON="$(usex python)"
		-DBUILD_SHARED_LIBS="$(usex shared)"
		-DBUILD_TESTS="$(usex test)"
	)
	if use python; then
		opengv_configure() {
			local mycmakeargs=(
				"${mycmakeargs[@]}"
				-DPython_EXECUTABLE="${PYTHON}"
			)
			cmake_src_configure
		}
		python_foreach_impl opengv_configure
	else
		cmake_src_configure
	fi
}

src_compile() {
	if use python; then
		pangolin_compile() {
			if [[ $(${PYTHON} -V) == $(python -V) ]]; then
				cmake_src_compile all
			else
				cmake_src_compile pypangolin
			fi
		}
		python_foreach_impl pangolin_compile
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
		opengv_install() {
			if [[ $(${PYTHON} -V) == $(python -V) ]]; then
				cmake_src_install
			fi
			python_domodule "${BUILD_DIR}"/lib64/pyopengv*.so
			rm "${ED}/usr/pyopengv"*.so
		}
		python_foreach_impl opengv_install
	else
		cmake_src_install
	fi
}
