# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

WX_GTK_VER="3.2-gtk3"
MY_PN="SuperSlicer"
SLICER_PROFILES_COMMIT="ca25c7ec55dcc6073da61e39692c321cdb6497dc"

inherit cmake wxwidgets xdg flag-o-matic

DESCRIPTION="A mesh slicer to generate G-code for fused-filament-fabrication (3D printers)"
HOMEPAGE="https://github.com/supermerill/SuperSlicer/"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/supermerill/SuperSlicer.git"
else
	SRC_URI="
		https://github.com/supermerill/SuperSlicer/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/slic3r/slic3r-profiles/archive/${SLICER_PROFILES_COMMIT}.tar.gz
			-> slic3r-profiles-${SLICER_PROFILES_COMMIT:0:8}.tar.gz
	"
	S="${WORKDIR}/${MY_PN}-${PV}"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="AGPL-3 Boost-1.0 GPL-2 LGPL-3 MIT"
SLOT="0"
IUSE="test"

RESTRICT="test"

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
	x11-libs/wxGTK:${WX_GTK_VER}[X,opengl]
"
DEPEND="${RDEPEND}
	dev-cpp/eigen:3=
	media-libs/qhull[static-libs]
	test? ( =dev-cpp/catch-2* )
"

PATCHES=(
	"${FILESDIR}/${PN}-2.5.59.2-cereal.patch"
	"${FILESDIR}/${PN}-2.5.59.2-dont-install-angelscript.patch"
	"${FILESDIR}/${PN}-2.5.59.2-openexr3.patch"
	"${FILESDIR}/${PN}-2.5.59.2-wxgtk3-wayland-fix.patch"
	"${FILESDIR}/${PN}-2.5.59.2-relax-OpenCASCADE-dep.patch"
	"${FILESDIR}/${PN}-2.5.59.2-link-occtwrapper-statically.patch"

	"${FILESDIR}/${PN}-2.5.59.8-fix-compilation-error-gnu17.patch"
	"${FILESDIR}/${PN}-2.5.59.8-libnest2d-link-xcb.patch"
	"${FILESDIR}/${PN}-2.5.59.8-boost-replace-load-string-file.patch"

	"${FILESDIR}/${PN}-2.5.59.13-make-unambiguous.patch"
	"${FILESDIR}/${PN}-2.5.59.13-boost-1.87.patch"
	"${FILESDIR}/${PN}-2.5.59.13-cstdint.patch"
	"${FILESDIR}/${PN}-2.5.59.13-fstream.patch"
	"${FILESDIR}/${PN}-2.5.59.13-header-cleanup.patch"

	"${FILESDIR}/${PN}-2.5.60.0-cmp0175.patch"
	"${FILESDIR}/${PN}-2.5.60.0-cmp0175-build-utils.patch"
	"${FILESDIR}/${PN}-2.5.60.0-find-libigl.patch"
	"${FILESDIR}/${PN}-2.5.60.0-boost-1.88.patch"
	"${FILESDIR}/${PN}-2.5.60.0-eigen-5.patch"
)

src_unpack() {
	default

	mv slic3r-profiles-*/* "${S}"/resources/profiles/ || die
}

src_prepare() {
	cmake_src_prepare

	if has_version ">=sci-libs/opencascade-7.8.0"; then
		eapply "${FILESDIR}/${PN}-2.5.59.13-opencascade-7.8.0.patch"
	fi

	sed -e '/find_package(Boost/s/)/ CONFIG)/g' -i CMakeLists.txt

	sed -re "/cmake_minimum_required/s/(VERSION [0-9]+\.[0-9]+)(\.[0-9]+)?/\1\2...3.10/" \
		-i \
			src/Shiny/CMakeLists.txt \
			src/admesh/CMakeLists.txt \
			src/angelscript/CMakeLists.txt \
			src/avrdude/CMakeLists.txt \
			src/boost/CMakeLists.txt \
			src/clipper/CMakeLists.txt \
			src/exif/CMakeLists.txt \
			src/glu-libtess/CMakeLists.txt \
			src/imgui/CMakeLists.txt \
			src/jpeg-compressor/CMakeLists.txt \
			src/libigl/CMakeLists.txt \
			src/miniz/CMakeLists.txt \
			src/qhull/CMakeLists.txt \
			src/qoi/CMakeLists.txt \
			src/semver/CMakeLists.txt \
			tests/cpp17/CMakeLists.txt \
		|| die

	pushd cmake/modules >/dev/null || die
	local cmake_duplicates=(
		"FindCURL.cmake"
		"FindEigen3.cmake"
		"FindEXPAT.cmake"
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
	: "${CMAKE_BUILD_TYPE:="Release"}"

	# append-flags -fno-strict-aliasing

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
		-DSLIC3R_LOG_TO_FILE="yes"
		# -DSLIC3R_PERL_XS="$(usex perl)"
		-DSLIC3R_PERL_XS="no"
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	rm "${ED}/usr/lib/udev/rules.d/90-3dconnexion.rules" || die
}
