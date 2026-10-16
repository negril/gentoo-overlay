# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit cmake python-single-r1

MY_PN="OpenTimelineIO"

DESCRIPTION="Open Source API and interchange format for editorial timeline information"
HOMEPAGE="
	https://opentimeline.io
	https://github.com/AcademySoftwareFoundation/OpenTimelineIO
"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/AcademySoftwareFoundation/OpenTimelineIO.git"
	EGIT_SUBMODULES=(
		'-*'
	)
else
	SRC_URI="
		https://github.com/AcademySoftwareFoundation/OpenTimelineIO/archive/refs/tags/v${PV}.tar.gz
			-> ${MY_PN}-${PV}.tar.gz
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64 ~arm64 ~ppc64 ~riscv ~x86"
fi

LICENSE="Apache-2.0"
SLOT="0/$(ver_cut 1-2)"
IUSE="+cli +python test"

RESTRICT="!test? ( test )"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
"
RDEPEND="
	dev-libs/imath:=
	sys-libs/minizip-ng:=
	python? (
		${PYTHON_DEPS}
	)
"
DEPEND="
	${RDEPEND}
"

DOCS=(
	README.md
)

PATCHES=(
	"${FILESDIR}/${PN}-Gentoo-specific-Install-CXX-to-default-location.patch"
)

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_unpack() {
	if [[ ${PV} = *9999* ]] ; then
		git-r3_src_unpack
	else
		default
	fi
}

src_prepare() {
	cmake_src_prepare

	sed \
		-e "s|\(set(OTIO_RESOLVED_CXX_DYLIB_INSTALL_DIR \"\${CMAKE_INSTALL_PREFIX}/\)lib\")|\1$(get_libdir)\")|" \
		-i CMakeLists.txt || die

	sed \
		-e "/\/lib\/cmake\/opentime/s,/lib/,/$(get_libdir)/,g" \
		-i src/opentime{,lineio}/CMakeLists.txt || die
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTING="$(usex test)"

		-DOTIO_AUTOMATIC_SUBMODULES="no"
		-DOTIO_DEPENDENCIES_INSTALL="no"
		# avoid breaking
		-DOTIO_DEBUG_POSTFIX=""
		-DOTIO_SHARED_LIBS="yes"

		-DOTIO_FIND_IMATH="yes"
		-DOTIO_FIND_MINIZIP_NG="yes"
		-DOTIO_FIND_PYBIND11="$(usex python)"
		-DOTIO_FIND_RAPIDJSON="yes"

		-DOTIO_CXX_COVERAGE="no"
		-DOTIO_CXX_EXAMPLES="no"
		-DOTIO_CXX_INSTALL="yes"

		-DOTIO_PYTHON_INSTALL="$(usex python)"
	)

	if use python; then
		mycmakeargs+=(
			# -DCMAKE_POLICY_DEFAULT_CMP0148="OLD" # FindPythonInterp
			-DOTIO_INSTALL_COMMANDLINE_TOOLS="$(usex cli)"

			-DOTIO_INSTALL_PYTHON_MODULES="yes"
			-DOTIO_PYTHON_INSTALL_DIR="$(python_get_sitedir)"
			-DPython_EXECUTABLE="${PYTHON}"
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	if use python; then
		python_optimize

		# mv "${ED}/usr/$(get_libdir)"/_{opentime,otio}* "${D}/$(python_get_sitedir)/${PN}" || die
	fi
}
