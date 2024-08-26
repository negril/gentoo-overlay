# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
# CMAKE_BUILD_TYPE="Release"
inherit cmake desktop python-single-r1 xdg

DESCRIPTION="Automatic 3d tetrahedral mesh generator"
HOMEPAGE="https://ngsolve.org/ https://github.com/NGSolve/netgen"
SRC_URI="https://github.com/NGSolve/netgen/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="ffmpeg gui jpeg mpi +opencascade python test"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	ffmpeg? ( gui )
	jpeg? ( gui )
	python? ( gui )
"

DEPEND="
	sys-libs/zlib
	ffmpeg? ( media-video/ffmpeg:= )
	gui? (
		dev-lang/tcl:0/8.6
		dev-lang/tk:0/8.6
		media-libs/glu
		media-libs/libglvnd[X]
		x11-libs/libX11
		x11-libs/libXmu
		x11-libs/libxcb:=
	)
	jpeg? ( media-libs/libjpeg-turbo:0= )
	mpi? (
		sci-libs/metis
		virtual/mpi
	)
	opencascade? ( sci-libs/opencascade:= )
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
			'
		)
		mpi? (
			$(python_gen_cond_dep 'dev-python/mpi4py[${PYTHON_USEDEP}]' )
		)
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	sys-apps/lsb-release
	virtual/pkgconfig
	gui? ( virtual/imagemagick-tools[png] )
	test? (
		<dev-cpp/catch-3:0
		python? ( $(python_gen_cond_dep '
			dev-python/pytest-check[${PYTHON_USEDEP}]
		') )
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-6.2.2204-find-Tk-include-directories.patch"
	"${FILESDIR}/${PN}-6.2.2404-link-against-ffmpeg.patch"
	"${FILESDIR}/${PN}-6.2.2204-use-system-catch.patch"
	"${FILESDIR}/${PN}-6.2.2404-find-libjpeg-turbo-library.patch"
	"${FILESDIR}/${PN}-6.2.2301-fix-nullptr-deref-in-archive.patch"
	"${FILESDIR}/${PN}-6.2.2404-encoding_h.patch"
	"${FILESDIR}/${PN}-6.2.2404-git_version_string.patch"
	"${FILESDIR}/${PN}-6.2.2404-fix-LTO-Line-basegeom.patch"
)

pkg_setup() {
	if use python; then
		python-single-r1_pkg_setup

		# NOTE This calls find_package(Python3) without specifying Interpreter in COMPONENTS.
		# Python3_FIND_UNVERSIONED_NAMES=FIRST is thus never checked and we search the highest python version first.
		pushd "${T}/${EPYTHON}/bin" > /dev/null || die
		cp "python-config" "${EPYTHON}-config" || die
		chmod +x "${EPYTHON}-config" || die
		popd > /dev/null || die
	fi
}

src_prepare() {
	rm external_dependencies -r || die

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# NOTE: need to manually check and update this string on version bumps!
		# git describe --tags --match "v[0-9]*" --long --dirty
		# https://github.com/NGSolve/netgen/tags
		-DNETGEN_VERSION_GIT="v${PV}-0-c488fa9"

		# currently not working in a sandbox, expects netgen to be installed
		# see https://github.com/NGSolve/netgen/issues/132
		-DBUILD_STUB_FILES=OFF
		-DENABLE_UNIT_TESTS="$(usex test)"
		-DCHECK_RANGE="$(usex test)"
		-DINSTALL_PROFILES=OFF
		-DNG_INSTALL_DIR_CMAKE="$(get_libdir)/cmake/${PN}"
		-DNG_INSTALL_DIR_INCLUDE="include/${PN}"
		-DNG_INSTALL_DIR_LIB="$(get_libdir)"
		-DUSE_CCACHE=OFF
		# doesn't build with this version
		-DUSE_CGNS=OFF
		-DUSE_GUI="$(usex gui)"
		-DUSE_INTERNAL_TCL=OFF
		-DUSE_JPEG="$(usex jpeg)"
		-DUSE_MPEG="$(usex ffmpeg)"
		# respect users -march= choice
		-DUSE_NATIVE_ARCH=OFF
		-DUSE_MPI="$(usex mpi)"
		-DUSE_OCC="$(usex opencascade)"
		-DUSE_PYTHON="$(usex python)"
		-DUSE_SUPERBUILD=OFF
	)
	# no need to set this, if we only build the library
	if use gui; then
		mycmakeargs+=( -DTK_INCLUDE_PATH="${EPREFIX}/usr/$(get_libdir)/tk8.6/include" )
	fi
	if use python; then
		mycmakeargs+=(
			-DPREFER_SYSTEM_PYBIND11=ON
			# # needed, so the value gets passed to NetgenConfig.cmake instead of ${T}/pythonX.Y
			-DPython3_EXECUTABLE="${PYTHON}"
		)
	fi
	if use mpi && use python; then
		mycmakeargs+=( -DUSE_MPI4PY=ON )
	else
		mycmakeargs+=( -DUSE_MPI4PY=OFF )
	fi
	cmake_src_configure
}

src_test() {
	DESTDIR="${T}" cmake_build install

	if use python; then
		local -x PYTHONPATH="${T}/$(python_get_sitedir):${T}/usr/$(get_libdir):${BUILD_DIR}/libsrc/core"
	fi

	CMAKE_SKIP_TESTS=(
		'^pytest$' # SEGFAULT
	)
	cmake_src_test
}

src_install() {
	cmake_src_install
	use python && python_optimize

	local NETGENDIR="${EPREFIX}/usr/share/${PN}"
	echo -e "NETGENDIR=${NETGENDIR}" > ./99netgen || die
	doenvd 99netgen

	if use gui; then
		mv "${ED}"/usr/bin/{*.tcl,*.ocf} "${ED}${NETGENDIR}" || die

		magick convert -deconstruct "${S}/windows/${PN}.ico" netgen.png || die
		newicon -s 32 "${S}"/${PN}-2.png ${PN}.png
		newicon -s 16 "${S}"/${PN}-3.png ${PN}.png
		make_desktop_entry ${PN} "Netgen" netgen Graphics
	fi

	mv "${ED}/usr/share/${PN}/doc/ng4.pdf" "${ED}/usr/share/doc/${PF}" || die
	dosym -r "/usr/share/doc/${PF}/ng4.pdf" "/usr/share/${PN}/doc/ng4.pdf"

	use python || rm -r "${ED}${NETGENDIR}/py_tutorials" || die
}