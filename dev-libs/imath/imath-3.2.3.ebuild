# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# TODO
# add hip
# boost[python] -> pybind11 -DPYBIND11=ON
# add SONAME version check from IMATH_LIB_SOVERSION

PYTHON_COMPAT=( python3_{12..14} )

inherit cmake python-single-r1

MY_PN=${PN^}

DESCRIPTION="Imath basic math package"
HOMEPAGE="https://imath.readthedocs.io https://github.com/AcademySoftwareFoundation/Imath"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/AcademySoftwareFoundation/Imath.git"

	MY_SONAME="9999"
else
	SRC_URI="https://github.com/AcademySoftwareFoundation/${MY_PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64 ~arm ~arm64 ~hppa ~loong ~ppc ~ppc64 ~riscv ~sparc ~x86"

	MY_SONAME="30"
fi

LICENSE="BSD"

SLOT="3/${MY_SONAME}"

IUSE="doc large-stack python test"
REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"
RESTRICT="!test? ( test )"

RDEPEND="
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
			dev-python/numpy[${PYTHON_USEDEP}]
		')
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	doc? (
		app-text/doxygen
		$(python_gen_cond_dep '
			dev-python/breathe[${PYTHON_USEDEP}]
			dev-python/sphinx[${PYTHON_USEDEP}]
			dev-python/sphinx-press-theme[${PYTHON_USEDEP}]
		')
	)
	python? ( ${PYTHON_DEPS} )
"

DOCS=(
	CHANGES.md
	CONTRIBUTORS.md
	README.md
	SECURITY.md
)

PATCHES=(
	"${FILESDIR}/${PN}-3.2.2-fix-float-comp.patch" #981863
)

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_WEBSITE="$(usex doc)"
		-DIMATH_ENABLE_LARGE_STACK="$(usex large-stack)"
		# the following options are at their default value
		-DIMATH_HALF_USE_LOOKUP_TABLE=ON
		-DIMATH_INSTALL_PKG_CONFIG=ON
		-DIMATH_USE_CLANG_TIDY=OFF
		-DIMATH_USE_DEFAULT_VISIBILITY=OFF
		-DIMATH_USE_NOEXCEPT=ON
	)
	if use python; then
		mycmakeargs+=(
			-DPYTHON="no" # uses boost[python]
			-DPYBIND11="yes"  # uses pybind
			# -DPython3_EXECUTABLE="${EPYTHON}"
			# -DPython3_PREFIX="${ED}"
			# -DPython3_SITEARCH="${D}$(python_get_sitedir)"
			# -DPython3_INCLUDE_DIR="$(python_get_includedir)"
			# -DPython3_LIBRARY="$(python_get_library_path)"
			-DPYTHON_INSTALL_DIR="$(python_get_sitedir)"
		)
	fi

	cmake_src_configure
}

src_install() {
	if use doc; then
		local HTML_DOCS=(
			"${BUILD_DIR}/website/sphinx/."
		)
	fi

	cmake_src_install
}
