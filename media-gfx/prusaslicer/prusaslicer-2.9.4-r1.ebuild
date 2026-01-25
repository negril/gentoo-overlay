# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

WX_GTK_VER="3.2-gtk3"
MY_PN="PrusaSlicer"
MY_PV="$(ver_rs 3 -)"

CMAKE_BUILD_TYPE="Release"
inherit cmake wxwidgets xdg
inherit flag-o-matic
# inherit edo

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/prusa3d/prusaslicer.git"
else
	SRC_URI="https://github.com/prusa3d/PrusaSlicer/archive/refs/tags/version_${MY_PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64 ~x86"
	S="${WORKDIR}/${MY_PN}-version_${MY_PV}"
fi

DESCRIPTION="A mesh slicer to generate G-code for fused-filament-fabrication (3D printers)"
HOMEPAGE="https://www.prusa3d.com/prusaslicer/"

LICENSE="AGPL-3 Boost-1.0 GPL-2 LGPL-3 MIT"
SLOT="0"
IUSE="test"

RESTRICT="!test? ( test )"

RDEPEND="
	dev-cpp/eigen:=
	dev-cpp/tbb:=
	dev-libs/boost:=[nls]
	dev-libs/cereal
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/gmp:=
	dev-libs/mpfr:=
	media-gfx/libbgcode
	media-gfx/openvdb:=
	media-libs/glew:0=
	media-libs/libjpeg-turbo:=
	media-libs/libpng:0=
	media-libs/nanosvg:=
	media-libs/qhull:=[static-libs]
	net-libs/webkit-gtk:4.1[X]
	net-misc/curl[adns]
	sci-libs/libigl
	sci-libs/nlopt
	sci-libs/opencascade:=
	sci-mathematics/cgal:=
	sci-mathematics/z3:=
	sys-apps/dbus
	virtual/opengl[X]
	virtual/zlib:=
	x11-libs/gtk+:3
	x11-libs/wxGTK:${WX_GTK_VER}=[X,opengl,webkit]
"
DEPEND="${RDEPEND}
	dev-cpp/nlohmann_json
	test? (
		dev-cpp/catch
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-2.6.0-dont-force-link-to-wayland-and-x11.patch"

	"${FILESDIR}/${PN}-find-libigl.patch"
	"${FILESDIR}/${PN}-libigl.patch"
	"${FILESDIR}/${PN}-2.9.3-libigl-2.6.0.patch"
	"${FILESDIR}/${PN}-2.9.4-libigl-2.6.0-pt2.patch"

	"${FILESDIR}/${PN}-avrdude.patch"

	"${FILESDIR}/${PN}-2.8.1-cgal-6.0.patch"
	"${FILESDIR}/${PN}-2.9.4-CGAL-6.0-pt2.patch"

	"${FILESDIR}/${PN}-2.8.1-fstream.patch"

	"${FILESDIR}/${PN}-2.8.1-fix-libsoup-double-linking.patch"

	"${FILESDIR}/${PN}-2.8.1-boost-1.87.patch"
	"${FILESDIR}/${PN}-2.9.2-boost-1.88.patch"
	"${FILESDIR}/${PN}-2.9.4-boost-1.89.patch"

	"${FILESDIR}/${PN}-2.9.3-eigen-5.patch"
)

src_prepare() {
	if has_version ">=sci-libs/opencascade-7.8.0"; then
		eapply "${FILESDIR}/prusaslicer-2.8.1-opencascade-7.8.0.patch"
	fi

	sed -i -e 's/PrusaSlicer-${SLIC3R_VERSION}+UNKNOWN/PrusaSlicer-${SLIC3R_VERSION}+Gentoo/g' version.inc || die

	sed -i -e 's/find_package(OpenCASCADE 7.6.[0-9] REQUIRED)/find_package(OpenCASCADE REQUIRED)/g' \
		src/occt_wrapper/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	export CMAKE_POLICY_VERSION_MINIMUM="3.10"

	filter-lto

	append-cxxflags -Wno-overloaded-virtual
	append-cxxflags -Wno-unused-result
	append-cxxflags -Wno-unused-variable
	append-cxxflags -Wno-sign-compare
	append-cxxflags -Wno-unused-but-set-variable
	append-cxxflags -Wno-class-memaccess

	setup-wxwidgets

	local mycmakeargs=(
		-DCMAKE_POSITION_INDEPENDENT_CODE="yes"

		-DOPENVDB_FIND_MODULE_PATH="/usr/$(get_libdir)/cmake/OpenVDB"

		-DSLIC3R_ASAN=OFF
		-DSLIC3R_BUILD_SANDBOXES="OFF"
		-DSLIC3R_BUILD_TESTS="$(usex test)"
		-DSLIC3R_ENABLE_FORMAT_STEP=ON
		-DSLIC3R_FHS=ON
		-DSLIC3R_GTK=3
		-DSLIC3R_GUI=ON
		-DSLIC3R_LOG_TO_FILE=OFF
		-DSLIC3R_MSVC_COMPILE_PARALLEL=ON
		-DSLIC3R_OPENGL_ES=OFF
		-DSLIC3R_PCH=OFF
		-DSLIC3R_REPO_URL=OFF
		-DSLIC3R_STATIC=OFF
		-DSLIC3R_UBSAN=OFF
		-DSLIC3R_WX_STABLE=ON
		-Wno-dev
	)
# 	if use test; then
# 		mycmakeargs+=(
# 			-DCATCH_EXTRA_ARGS="-s;-d;yes"
# 		)
# 	fi

	cmake_src_configure
}

src_test() {
	CMAKE_SKIP_TESTS=(
	# 	"^libslic3r_tests$"
		"^libseqarrange_tests$"
	)
	local myctestargs=(
# 		--extra-verbose
		--output-on-failure
	)
	cmake_src_test

	# edo "${BUILD_DIR}/tests/arrange/arrange_tests" -s
# 	edo "${BUILD_DIR}/src/libseqarrange/libseqarrange_tests" "exclude:[NotWorking]" "exclude:[Slow]" -s -d yes
	# LC_ALL=en_US.UTF-8 /var/tmp/paludis/media-gfx-prusaslicer-2.9.4-r1/work/PrusaSlicer-version_2.9.4_build/src/libseqarrange/libseqarrange_tests 'exclude:[NotWorking]' 'exclude:[Slow]' -s --rng-seed=1878596494 -d yes
# '[Sequential Arrangement Core]' 'exclude:Sequential test 1' 'exclude:Sequential test 6'
# '[Polygon]'
# '[Sequential Arrangement Interface]' 'exclude:Interface test 4'
# # '[Sequential Arrangement Preprocessing]'

}
