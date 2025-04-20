# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

MY_PN="OpenTimelineIO"

# TODO move the python version to dev-python/opentimelineio
if [[ "${CATEGORY}" == "dev-python" ]]; then
PYTHON_COMPAT=( python3_{10..13} )
DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
DISTUTILS_OPTIONAL=1
inherit distutils-r1
fi

DESCRIPTION="Open Source API and interchange format for editorial timeline information"
HOMEPAGE="
	https://github.com/AcademySoftwareFoundation/OpenTimelineIO
	https://opentimeline.io
"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/AcademySoftwareFoundation/OpenTimelineIO.git"
	EGIT_SUBMODULES=( )
else
	# if [[ "${CATEGORY}" == "dev-python" ]]; then
	# inherit pypi
	# fi

	# Rapidjson hasn't had a release since 2016. OpenTimelineIO builds against rapidjson HEAD.
	RAPIDJSON_COMMIT="24b5e7a8b27f42fa16b96fc70aade9106cf7102f"

	SRC_URI="
		https://github.com/AcademySoftwareFoundation/OpenTimelineIO/archive/refs/tags/v${PV}.tar.gz
			-> ${MY_PN}-${PV}.tar.gz
		!system-rapidjson? (
			https://github.com/Tencent/rapidjson/archive/${RAPIDJSON_COMMIT}.tar.gz
				-> rapidjson-${RAPIDJSON_COMMIT}.tar.gz
		)
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="Apache-2.0"
SLOT="0/$(ver_cut 1-2)"
IUSE="+system-rapidjson test"
if [[ "${CATEGORY}" == "dev-python" ]]; then
IUSE+=" cli"
fi
RESTRICT="!test? ( test )"

if [[ "${CATEGORY}" == "dev-python" ]]; then
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
BDEPEND="${DISTUTILS_DEPS}"
COMMON_DEPEND="
	dev-python/pyside:6=[${PYTHON_USEDEP}]
"

RDEPEND="
	${COMMON_DEPEND}
	${PYTHON_DEPS}
"
DEPEND="
	${COMMON_DEPEND}
"
fi

DEPEND+="
	system-rapidjson? ( >dev-libs/rapidjson-1.1.0-r4 )
	dev-libs/imath:3
"

DOCS=(
	README.md
)

src_unpack() {
	if [[ ${PV} = *9999* ]] ; then
		if ! use system-rapidjson; then
			EGIT_SUBMODULES+=( 'src/deps/rapidjson' )
		fi
		git-r3_src_unpack
	else
		default
	fi
}

src_prepare() {
	if [[ "${PV}" != *9999* ]] && ! use system-rapidjson; then
		mv -T "${WORKDIR}/rapidjson-${RAPIDJSON_COMMIT}" "src/deps/rapidjson" || die
	fi

	sed \
		-e "s|\(set(OTIO_RESOLVED_CXX_DYLIB_INSTALL_DIR \"\${CMAKE_INSTALL_PREFIX}/\)lib\")|\1$(get_libdir)\")|" \
		-i CMakeLists.txt || die

	sed \
		"s|share/opentime|$(get_libdir)/cmake/opentime|g" \
		-i src/opentime{,lineio}/CMakeLists.txt || die

	# sed \
	# 	"/set(OTIO_RESOLVED_CXX_DYLIB_INSTALL_DIR/ {
	# 		s|\(\${CMAKE_INSTALL_PREFIX}\)/lib)|\1/$(get_libdir)|
	# 	}" -i CMakeLists.txt || die

	if [[ "${CATEGORY}" == "dev-python" ]]; then
		sed -re '/.*: OTIO_build_ext,/d' -i setup.py || die
		sed -e 's/add_subdirectory(pybind11)/find_package(pybind11 CONFIG REQUIRED GLOBAL)/g' \
			-i src/deps/CMakeLists.txt || die

		distutils-r1_python_prepare_all
	fi

	cmake_src_prepare
}

cxx_configure() {
	mycmakeargs+=(
		-DOTIO_CXX_INSTALL="yes"

		-DOTIO_PYTHON_INSTALL="no"
	)
	cmake_src_configure
}

if [[ "${CATEGORY}" == "dev-python" ]]; then
python_configure(){
	mycmakeargs+=(
		-DOTIO_CXX_INSTALL="no"

		# -DOTIO_INSTALL_CONTRIB="no"
		-DOTIO_INSTALL_COMMANDLINE_TOOLS="$(usex cli)"

		-DOTIO_INSTALL_PYTHON_MODULES="yes"
		-DOTIO_PYTHON_INSTALL="yes"
		-DOTIO_PYTHON_INSTALL_DIR="$(python_get_sitedir)"
		-DPython_EXECUTABLE="${PYTHON}"
	)
	cmake_src_configure
}
fi

src_configure() {
	local mycmakeargs=(
		-DOTIO_CXX_COVERAGE="no"
		-DOTIO_CXX_EXAMPLES="no"
		-DOTIO_DEPENDENCIES_INSTALL="no"

		-DBUILD_TESTING="$(usex test)"
		-DOTIO_AUTOMATIC_SUBMODULES="no"

		-DOTIO_FIND_RAPIDJSON="$(usex system-rapidjson)"
		-DOTIO_FIND_IMATH="yes"
		-DOTIO_IMATH_LIBS=""
		-DOTIO_SHARED_LIBS="yes"
	)
	if [[ "${CATEGORY}" == "dev-python" ]]; then
		distutils-r1_src_configure
	else
		cxx_configure
	fi
}

python_compile() {
	cmake_src_compile
	distutils-r1_python_compile
}

src_compile() {
	cmake_src_compile

	if [[ "${CATEGORY}" == "dev-python" ]]; then
		distutils-r1_src_compile
	fi
}

python_test() {
	cmake_src_test
}

src_test() {
	cmake_src_test

	if [[ "${CATEGORY}" == "dev-python" ]]; then
		distutils-r1_src_test
	fi
}

python_install() {
	cmake_src_install

	distutils-r1_python_install
}

src_install() {
	cmake_src_install

	if [[ "${CATEGORY}" == "dev-python" ]]; then
		distutils-r1_src_install
	fi
}
