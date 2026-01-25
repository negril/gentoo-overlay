# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

WX_GTK_VER="3.2-gtk3"
MY_PN="OrcaSlicer"
# SLICER_PROFILES_COMMIT="ca25c7ec55dcc6073da61e39692c321cdb6497dc"

inherit cmake wxwidgets xdg flag-o-matic

DESCRIPTION="G-code generator for 3D printers (Bambu, Prusa, Voron, VzBot, RatRig, Creality, etc.)"
HOMEPAGE="https://github.com/SoftFever/OrcaSlicer"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/SoftFever/OrcaSlicer.git"
else
	SRC_URI="
		https://github.com/SoftFever/${MY_PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="AGPL-3 Boost-1.0 GPL-2 LGPL-3 MIT"
SLOT="0"
IUSE="perl test"

RESTRICT="!test? ( test )"

RDEPEND="
	dev-cpp/tbb:=
	dev-libs/boost:=[nls]
	dev-libs/cereal
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/gmp:=
	dev-libs/mpfr:=
	dev-libs/imath:=
	media-gfx/openvdb:=
	net-misc/curl[adns]
	media-libs/glew:0=
	media-libs/libnoise
	media-libs/libpng:0=
	media-libs/qhull:=
	sci-libs/libigl
	sci-libs/nlopt
	sci-libs/opencascade:=
	sci-mathematics/cgal:=
	sys-apps/dbus
	virtual/zlib:=
	virtual/glu
	virtual/opengl
	x11-libs/gtk+:3
	x11-libs/wxGTK:${WX_GTK_VER}[X,curl,opengl,webkit]
	perl? (
		dev-perl/ExtUtils-CppGuess
		dev-perl/ExtUtils-Typemaps-Default
		dev-perl/ExtUtils-XSpp
	)
"
DEPEND="${RDEPEND}
	dev-cpp/eigen:3=
	media-libs/qhull[static-libs]
	test? (
		=dev-cpp/catch-2*
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-2.3.0-full.patch"
	"${FILESDIR}/${PN}-2.3.0-fix-wx.patch"

# 	"${FILESDIR}/${PN}-2.2.0-cmp0175.patch"
# 	"${FILESDIR}/${PN}-2.2.0-cmp0175-build-utils.patch"
# 	"${FILESDIR}/${PN}-2.3.0-find-libigl.patch"
# 	"${FILESDIR}/${PN}-2.3.0-misc.patch"
# 	"${FILESDIR}/${PN}-2.3.0-cstdint.patch"
# 	"${FILESDIR}/prusaslicer-2.8.1-cgal-6.0.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix1.patch" # cgal
# 	"${FILESDIR}/${PN}-2.3.0-make-unambiguous.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix2.patch" # make-unambiguous
#
# 	"${FILESDIR}/${PN}-2.3.0-boost-1.87.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix5.patch"
# 	"${FILESDIR}/${PN}-2.3.0-boost-1.88.patch"
# 	# "${FILESDIR}/${PN}-2.2.0-fix-boost.patch"
#
# 	"${FILESDIR}/${PN}-2.3.0-opencascade-7.8.0.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix4.patch"
# 	"${FILESDIR}/${PN}-2.3.0-opencv-imgproc.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix3.patch"
# 	"${FILESDIR}/${PN}-2.3.0-eigen-cmake-config.patch"
# 	"${FILESDIR}/${PN}-2.3.0-drop-osmesa.patch"
# 	"${FILESDIR}/${PN}-2.3.0-link-webkit2gtk.patch"
#
#
# 	"${FILESDIR}/${PN}-2.2.0-fix-wx.patch"
# 	"${FILESDIR}/${PN}-2.2.0-fix-install-path.patch"
# 	"${FILESDIR}/7057.patch" # tbb
# 	"${FILESDIR}/7591.patch" # Fix webview blank issue on Linux; Cherry-picked from prusa3d/PrusaSlicer@c3ca39d5c5458a58402abe737ef90c061b76aeb5
#
# 	"${FILESDIR}/${PN}-2.3.0-fix6.patch"
# 	# "${FILESDIR}/${PN}-2.3.0-fix-libnoise.patch"
# 	# "${FILESDIR}/6204.patch" # blurry stuff

	"${FILESDIR}/${PN}-2.3.0-eigen-5.patch"
)

src_prepare() {
	cmake_src_prepare

# 	git am "${FILESDIR}/6204.patch" # blurry stuff

	sed -e '/find_package(Boost/s/)/ CONFIG)/g' -i CMakeLists.txt

	# sed -re "/cmake_minimum_required/s/(VERSION [0-9]+\.[0-9]+)(\.[0-9]+)?/\1\2...3.10/" \
	# 	-i \
	# 		src/Shiny/CMakeLists.txt \
	# 		src/admesh/CMakeLists.txt \
	# 		src/boost/CMakeLists.txt \
	# 		src/clipper/CMakeLists.txt \
	# 		src/glu-libtess/CMakeLists.txt \
	# 		src/imgui/CMakeLists.txt \
	# 		src/libigl/CMakeLists.txt \
	# 		src/miniz/CMakeLists.txt \
	# 		src/qhull/CMakeLists.txt \
	# 		src/qoi/CMakeLists.txt \
	# 		src/semver/CMakeLists.txt \
	# 		tests/cpp17/CMakeLists.txt \
	# 	|| die

	pushd cmake/modules >/dev/null || die
	local cmake_duplicates=(
		"FindCURL.cmake"
		"FindEigen3.cmake"
		# "FindEXPAT.cmake"
		"FindGLEW.cmake"
		"FindTBB.cmake"
		"FindOpenVDB.cmake"
		"OpenVDBUtils.cmake"
	)
	rm "${cmake_duplicates[@]}" || die
	popd >/dev/null || die

	sed -e "s/libexpat/expat/" \
		-i \
			src/CMakeLists.txt \
			src/libslic3r/CMakeLists.txt \
		|| die
}

src_configure() {
	CMAKE_BUILD_TYPE="Release"
	export CMAKE_POLICY_VERSION_MINIMUM="3.10"

	# append-flags -fno-strict-aliasing
	filter-lto
	append-flags -Wno-maybe-uninitialized
	append-cflags -Wno-old-style-definition
	append-cxxflags -Wno-overloaded-virtual

	setup-wxwidgets

	local mycmakeargs=(
		# Force finding system igl
		-DCMAKE_PREFIX_PATH="${ESYSROOT}/usr/$(get_libdir)/cmake/libigl"
		-DCMAKE_MODULE_PATH="${ESYSROOT}/usr/$(get_libdir)/cmake/OpenVDB"

		-DOPENVDB_FIND_MODULE_PATH="${ESYSROOT}/usr/$(get_libdir)/cmake/OpenVDB"

		-DSLIC3R_BUILD_TESTS="$(usex test)"
		-DSLIC3R_FHS="yes"
		-DSLIC3R_GTK="3"
		-DSLIC3R_GUI="yes"
		-DSLIC3R_PCH="no"
		-DSLIC3R_STATIC="no"
		-DORCA_TOOLS="yes"
		-DSLIC3R_LOG_TO_FILE="yes"
		-DSLIC3R_PERL_XS="$(usex perl)"
	)

	cmake_src_configure
}

src_compile() {
	cmake_src_compile OrcaSlicer OrcaSlicer_profile_validator
	./run_gettext.sh
}

# src_install() {
# 	cmake_src_install
#
# # 	rm "${ED}/usr/lib/udev/rules.d/90-3dconnexion.rules" || die
# }
