# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit cmake python-single-r1

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/wdas/partio.git"
else
	SRC_URI="https://github.com/wdas/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~x86"
fi

DESCRIPTION="Library for particle IO and manipulation"
HOMEPAGE="https://partio.us/"

LICENSE="BSD"
SLOT="0"
IUSE="doc python test tools"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
"

RDEPEND="
	python? (
		${PYTHON_DEPS}
	)
	tools? (
		media-libs/freeglut
		media-libs/glu
		virtual/opengl
	)
	virtual/zlib:=
"

DEPEND="${RDEPEND}
	test? (
		dev-cpp/gtest
	)
"

BDEPEND="
	python? (
		dev-lang/swig
	)
	doc? (
		app-text/doxygen
		dev-texlive/texlive-bibtexextra
		dev-texlive/texlive-fontsextra
		dev-texlive/texlive-fontutils
		dev-texlive/texlive-latex
		dev-texlive/texlive-latexextra
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-1.20.0-fix-python-install-dir.patch"
)

src_configure() {
	local mycmakeargs=(
		-DPARTIO_ENABLE_TESTING="$(usex test)" # "Enable testing"
		-DPARTIO_ORIGIN_RPATH="OFF" # "Enable ORIGIN rpath in the installed libraries"

		-DPARTIO_USE_GLVND="ON" # "Use GLVND for OpenGL"
		-DPARTIO_BUILD_SHARED_LIBS="ON" # "Enabled shared libraries"

		-DPARTIO_BUILD_DOCS="$(usex doc)"
		-DPARTIO_BUILD_PYTHON="$(usex python)"
		-DPARTIO_BUILD_TOOLS="$(usex tools)"
	)
	if use python; then
		mycmakeargs+=(
			-DPython_EXECUTABLE="${PYTHON}"
			-DPYTHON_DEST="$(python_get_sitedir)" #922965
		)
	fi

	cmake_src_configure
}

src_test() {
	#889567
	# for libpartio.so.1
	local -x LD_LIBRARY_PATH="${BUILD_DIR}/src/lib"

	local CMAKE_SKIP_TESTS=(
	)

	if use python; then
		# for import partjson, partio
		local -x PYTHONPATH="${BUILD_DIR}/src/py:${CMAKE_USE_DIR}/src/tools"
	else
		CMAKE_SKIP_TESTS+=(
			"^testpartio$"
			"^testpartjson$"
		)
	fi

	cmake_src_test
}

src_install() {
	cmake_src_install

	python_optimize

	# only remove test binaries when they are built #955625
	if use test; then
		rm -r "${ED}/usr/share/partio" || die
	fi
}
