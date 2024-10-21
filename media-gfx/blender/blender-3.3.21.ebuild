# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..11} )
# NOTE must match media-libs/osl
LLVM_COMPAT=( {15..18} )
LLVM_OPTIONAL=1

inherit check-reqs cmake cuda flag-o-matic llvm-r1 pax-utils python-single-r1 toolchain-funcs xdg-utils

DESCRIPTION="3D Creation/Animation/Publishing System"
HOMEPAGE="https://www.blender.org"

# NOTE BLENDER_VERSION https://projects.blender.org/blender/blender/src/branch/main/source/blender/blenkernel/BKE_blender_version.h
BLENDER_RELEASE=4.3
BLENDER_BRANCH="$(ver_cut 1-2)"

if [[ ${PV} = *9999* ]] ; then
	EGIT_LFS="yes"
	inherit git-r3
	EGIT_REPO_URI="https://projects.blender.org/blender/blender.git"
	EGIT_SUBMODULES=( '*' '-lib/*' )
	if ver_test "${BLENDER_BRANCH}" -lt "4.2"; then
		ADDONS_EGIT_REPO_URI="https://projects.blender.org/blender/blender-addons.git"
	fi

	if ver_test "${BLENDER_BRANCH}" -lt "${BLENDER_RELEASE}"; then
		EGIT_BRANCH="blender-v${BLENDER_BRANCH}-release"
	fi

	RESTRICT="!test? ( test )"
else
	SRC_URI="
		https://download.blender.org/source/${P}.tar.xz
	"
	# 	test? (
	# 		https://projects.blender.org/blender/blender-test-data/archive/blender-v${BLENDER_BRANCH}-release.tar.gz
	# 	)
	# "
	KEYWORDS="~amd64 ~arm ~arm64"
	RESTRICT="test" # the test archive returns LFS references.
fi

LICENSE="GPL-3+ cycles? ( Apache-2.0 )"
SLOT="${BLENDER_BRANCH}"

# NOTE +openpgl breaks on very old amd64 hardware
IUSE="
	+bullet +dds +fluid +openexr +tbb
	alembic collada +color-management cuda +cycles
	debug doc +embree +ffmpeg +fftw +gmp headless jack jemalloc jpeg2k
	man +nanovdb ndof nls openal +oidn +openimageio +openmp +opensubdiv
	+openvdb optix osl +pdf +potrace +pugixml pulseaudio sdl
	+sndfile test +tiff valgrind
"

REQUIRED_USE="${PYTHON_REQUIRED_USE}
	alembic? ( openexr )
	cuda? ( cycles )
	cycles? ( openexr tiff openimageio )
	fluid? ( tbb )
	openvdb? ( tbb )
	optix? ( cuda )
	osl? ( cycles )
	test? ( color-management )"

# Library versions for official builds can be found in the blender source directory in:
# build_files/build_environment/install_deps.sh
#
# <opencolorio-2.3.0 for https://projects.blender.org/blender/blender/issues/112917.
RDEPEND="${PYTHON_DEPS}
	dev-libs/boost:=[nls?]
	dev-libs/lzo:2=
	$(python_gen_cond_dep '
		dev-python/cython[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/zstandard[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
	')
	media-libs/freetype:=[brotli]
	media-libs/glew:*
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/libsamplerate
	sys-libs/zlib:=
	virtual/glu
	virtual/libintl
	virtual/opengl
	alembic? ( >=media-gfx/alembic-1.8.3-r2[boost(+),hdf(+)] )
	collada? ( >=media-libs/opencollada-1.6.68 )
	color-management? ( media-libs/opencolorio:= )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	embree? ( media-libs/embree:3[raymask] )
	ffmpeg? ( media-video/ffmpeg:=[x264,mp3,encode,theora,jpeg2k?,vpx,vorbis,opus,xvid] )
	fftw? ( sci-libs/fftw:3.0= )
	gmp? ( dev-libs/gmp[cxx] )
	!headless? (
		x11-libs/libX11
		x11-libs/libXi
		x11-libs/libXxf86vm
	)
	jack? ( virtual/jack )
	jemalloc? ( dev-libs/jemalloc:= )
	jpeg2k? ( media-libs/openjpeg:2= )
	ndof? (
		app-misc/spacenavd
		dev-libs/libspnav
	)
	nls? ( virtual/libiconv )
	openal? ( media-libs/openal )
	oidn? ( >=media-libs/oidn-1.4.1[${LLVM_USEDEP}] )
	openimageio? ( >=media-libs/openimageio-2.3.12.0-r3:= )
	openexr? (
		>=dev-libs/imath-3.1.4-r2:=
		>=media-libs/openexr-3:0=
	)
	opensubdiv? ( >=media-libs/opensubdiv-3.4.0 )
	openvdb? (
		>=media-gfx/openvdb-11.0.0:=[nanovdb?]
		dev-libs/c-blosc:=
	)
	optix? ( dev-libs/optix )
	osl? (
		<media-libs/osl-1.13:=[${LLVM_USEDEP}]
		media-libs/mesa[${LLVM_USEDEP}]
	)
	pdf? ( media-libs/libharu )
	potrace? ( media-gfx/potrace )
	pugixml? ( dev-libs/pugixml )
	pulseaudio? ( media-libs/libpulse )
	sdl? ( media-libs/libsdl2[sound,joystick] )
	sndfile? ( media-libs/libsndfile )
	tbb? ( dev-cpp/tbb:= )
	tiff? ( media-libs/tiff:= )
	valgrind? ( dev-debug/valgrind )
"

DEPEND="${RDEPEND}
	dev-cpp/eigen:=
"

BDEPEND="
	virtual/pkgconfig
	doc? (
		app-text/doxygen[dot]
		dev-python/sphinx[latex]
		dev-texlive/texlive-bibtexextra
		dev-texlive/texlive-fontsextra
		dev-texlive/texlive-fontutils
		dev-texlive/texlive-latex
		dev-texlive/texlive-latexextra
	)
	nls? ( sys-devel/gettext )
"

PATCHES=(
	"${FILESDIR}/${PN}-3.2.2-support-building-with-musl-libc.patch"
	"${FILESDIR}/${PN}-3.2.2-Cycles-add-option-to-specify-OptiX-runtime-root-dire.patch"
	"${FILESDIR}/${PN}-3.2.2-Fix-T100845-wrong-Cycles-OptiX-runtime-compilation-i.patch"
	"${FILESDIR}/${PN}-3.3.0-fix-build-with-boost-1.81.patch"
	"${FILESDIR}/${PN}-3.3.6-cycles-gcc13.patch"

	"${FILESDIR}/${PN}-4.0.1-openvdb-11.patch"
	"${FILESDIR}/${PN}-4.0.2-CUDA_NVCC_FLAGS.patch"
	"${FILESDIR}/${PN}-4.1.1-FindLLVM.patch"
)

blender_check_requirements() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp

	if use doc; then
		CHECKREQS_DISK_BUILD="4G" check-reqs_pkg_pretend
	fi
}

blender_get_version() {
	# Get blender version from blender itself.
	# NOTE maps x0y to x.y
	# TODO this can potentially break for x > 9 and y > 9
	BV=$(grep "BLENDER_VERSION " source/blender/blenkernel/BKE_blender_version.h | cut -d " " -f 3; assert)
	BV=${BV:0:1}.${BV:2}
}

pkg_pretend() {
	blender_check_requirements
}

pkg_setup() {
	if use osl; then
		llvm-r1_pkg_setup
	fi

	blender_check_requirements
	python-single-r1_pkg_setup
}

src_unpack() {
	if [[ ${PV} = *9999* ]] ; then
		if ! use test; then
			EGIT_SUBMODULES+=( '-tests/*' )
		fi
		git-r3_src_unpack

		# NOTE Add-ons bundled with Blender releases up to Blender 4.1. Blender 4.2 LTS and later include only a handful
		#      of core add-ons, while others are part of the Extensions Platform at https://extensions.blender.org
		ver_test "${BLENDER_BRANCH}" -ge "4.2" && return

		git-r3_fetch "${ADDONS_EGIT_REPO_URI}"
		git-r3_checkout "${ADDONS_EGIT_REPO_URI}" "${S}/scripts/addons"
	else
		default

		if use test; then
			mkdir -p "${S}/tests/data/" || die
			mv blender-test-data/* "${S}/tests/data/" || die
		fi
	fi
}

src_prepare() {
	use cuda && cuda_src_prepare

	cmake_src_prepare

	blender_get_version

	# Disable MS Windows help generation. The variable doesn't do what it
	# it sounds like.
	sed -e "s|GENERATE_HTMLHELP      = YES|GENERATE_HTMLHELP      = NO|" \
		-i doc/doxygen/Doxyfile || die

	# Prepare icons and .desktop files for slotting.
	sed \
		-e "s|blender.svg|blender-${BV}.svg|" \
		-e "s|blender-symbolic.svg|blender-${BV}-symbolic.svg|" \
		-e "s|blender.desktop|blender-${BV}.desktop|" \
		-e "s|org.blender.Blender.metainfo.xml|blender-${BV}.metainfo.xml|" \
		-i source/creator/CMakeLists.txt || die

	sed \
		-e "s|Name=Blender|Name=Blender ${BV}|" \
		-e "s|Exec=blender|Exec=blender-${BV}|" \
		-e "s|Icon=blender|Icon=blender-${BV}|" \
		-i release/freedesktop/blender.desktop || die

	sed \
		-e "/CMAKE_INSTALL_PREFIX_WITH_CONFIG/{s|\${CMAKE_INSTALL_PREFIX}|${T}/usr|g}" \
		-i CMakeLists.txt \
		|| die CMAKE_INSTALL_PREFIX_WITH_CONFIG

	mv \
		"release/freedesktop/icons/scalable/apps/blender.svg" \
		"release/freedesktop/icons/scalable/apps/blender-${BV}.svg" \
		|| die
	mv \
		"release/freedesktop/icons/symbolic/apps/blender-symbolic.svg" \
		"release/freedesktop/icons/symbolic/apps/blender-${BV}-symbolic.svg" \
		|| die
	mv \
		"release/freedesktop/blender.desktop" \
		"release/freedesktop/blender-${BV}.desktop" \
		|| die

	local info_file test_file
	if ver_test -ge 4; then
		info_file="metainfo"
		test_file="build_files/cmake/testing.cmake"
	else
		info_file="appdata"
		test_file="build_files/cmake/Modules/GTestTesting.cmake"
	fi
	mv \
		"release/freedesktop/org.blender.Blender.${info_file}.xml" \
		"release/freedesktop/blender-${BV}.${info_file}.xml" \
		|| die

	if use test; then
		# Without this the tests will try to use /usr/bin/blender and /usr/share/blender/ to run the tests.
		sed \
			-e "/string(REPLACE.*TEST_INSTALL_DIR/{s|\${CMAKE_INSTALL_PREFIX}|${T}/usr|g}" \
			-i "${test_file}" \
			|| die "REPLACE.*TEST_INSTALL_DIR"

		sed '1i #include <cstdint>' -i extern/gtest/src/gtest-death-test.cc || die
	fi

	unset info_file test_file
}

src_configure() {
	# -Werror=odr, -Werror=lto-type-mismatch
	# https://bugs.gentoo.org/859607
	# https://projects.blender.org/blender/blender/issues/120444
	filter-lto

	# Workaround for bug #922600
	append-ldflags $(test-flags-CCLD -Wl,--undefined-version)

	append-lfs-flags
	blender_get_version

	local mycmakeargs=(
		# we build a host-specific binary
		-DWITH_INSTALL_PORTABLE="no"

		-DBUILD_SHARED_LIBS="no" # this over-ridden by cmake.eclass

		-DPYTHON_INCLUDE_DIR="$(python_get_includedir)"
		-DPYTHON_LIBRARY="$(python_get_library_path)"
		-DPYTHON_VERSION="${EPYTHON/python/}"
		-DWITH_ALEMBIC=$(usex alembic)
		-DWITH_ASSERT_ABORT=$(usex debug)
		-DWITH_BOOST="yes"
		-DWITH_BULLET=$(usex bullet)
		-DWITH_CODEC_FFMPEG=$(usex ffmpeg)
		-DWITH_CODEC_SNDFILE=$(usex sndfile)
		-DWITH_CXX_GUARDEDALLOC=$(usex debug)
		-DWITH_CYCLES=$(usex cycles)
		-DWITH_CYCLES_DEVICE_CUDA=$(usex cuda TRUE FALSE)
		-DWITH_CYCLES_DEVICE_OPTIX=$(usex optix)
		-DWITH_CYCLES_EMBREE=$(usex embree)
		-DWITH_CYCLES_OSL=$(usex osl)
		-DWITH_CYCLES_STANDALONE="no"
		-DWITH_CYCLES_STANDALONE_GUI="no"
		-DWITH_DOC_MANPAGE=$(usex man)
		-DWITH_FFTW3=$(usex fftw)
		-DWITH_GMP=$(usex gmp)
		-DWITH_GTESTS=$(usex test)
		-DWITH_HARU=$(usex pdf)
		-DWITH_HEADLESS=$(usex headless)
		-DWITH_IMAGE_DDS=$(usex dds)
		-DWITH_IMAGE_OPENEXR=$(usex openexr)
		-DWITH_IMAGE_OPENJPEG=$(usex jpeg2k)
		-DWITH_IMAGE_TIFF=$(usex tiff)
		-DWITH_INPUT_NDOF=$(usex ndof)
		-DWITH_INTERNATIONAL=$(usex nls)
		-DWITH_JACK=$(usex jack)
		-DWITH_MEM_JEMALLOC=$(usex jemalloc)
		-DWITH_MEM_VALGRIND=$(usex valgrind)
		-DWITH_MOD_FLUID=$(usex fluid)
		-DWITH_MOD_OCEANSIM=$(usex fftw)
		-DWITH_NANOVDB=$(usex nanovdb)
		-DWITH_OPENAL=$(usex openal)
		-DWITH_OPENCOLLADA=$(usex collada)
		-DWITH_OPENCOLORIO=$(usex color-management)
		-DWITH_OPENIMAGEDENOISE=$(usex oidn)
		-DWITH_OPENIMAGEIO=$(usex openimageio)
		-DWITH_OPENMP=$(usex openmp)
		-DWITH_OPENSUBDIV=$(usex opensubdiv)
		-DWITH_OPENVDB=$(usex openvdb)
		-DWITH_OPENVDB_BLOSC=$(usex openvdb)
		-DWITH_POTRACE=$(usex potrace)
		-DWITH_PUGIXML=$(usex pugixml)
		-DWITH_PULSEAUDIO=$(usex pulseaudio)
		-DWITH_PYTHON_INSTALL="no"
		-DWITH_SDL=$(usex sdl)
		-DWITH_STATIC_LIBS="no"
		-DWITH_SYSTEM_EIGEN3="yes"
		-DWITH_SYSTEM_FREETYPE="yes"
		-DWITH_SYSTEM_GLEW="yes"
		-DWITH_SYSTEM_LZO="yes"
		-DWITH_TBB=$(usex tbb)
		-DWITH_USD="no"
		-DWITH_XR_OPENXR="no"
	)

	if has_version ">=dev-python/numpy-2"; then
		mycmakeargs+=(
			-DPYTHON_NUMPY_INCLUDE_DIRS="$(python_get_sitedir)/numpy/_core/include"
			-DPYTHON_NUMPY_PATH="$(python_get_sitedir)/numpy/_core/include"
		)
	fi

	# requires dev-vcs/git
	if [[ ${PV} = *9999* ]] ; then
		mycmakeargs+=( -DWITH_BUILDINFO="yes" )
	else
		mycmakeargs+=( -DWITH_BUILDINFO="no" )
	fi

	if use optix; then
		mycmakeargs+=(
			-DCYCLES_RUNTIME_OPTIX_ROOT_DIR="${EPREFIX}"/opt/optix
			-DOPTIX_ROOT_DIR="${EPREFIX}"/opt/optix
		)
	fi

	# This is currently needed on arm64 to get the NEON SIMD wrapper to compile the code successfully
	use arm64 && append-flags -flax-vector-conversions

	append-cflags "$(usex debug '-DDEBUG' '-DNDEBUG')"
	append-cppflags "$(usex debug '-DDEBUG' '-DNDEBUG')"

	if tc-is-gcc ; then
		# These options only exist when GCC is detected.
		# We disable these to respect the user's choice of linker.
		mycmakeargs+=(
			-DWITH_LINKER_GOLD="no"
			-DWITH_LINKER_LLD="no"
		)
		# Ease compiling with required gcc similar to cuda_sanitize but for cmake
		use cuda && use cycles-bin-kernels && mycmakeargs+=( -DCUDA_HOST_COMPILER="$(cuda_gccdir)" )
	fi

	if tc-is-clang || use osl; then
		mycmakeargs+=(
			-DWITH_CLANG="yes"
			-DWITH_LLVM="yes"
		)
	fi

	if use test ; then
		local CYCLES_TEST_DEVICES=( "CPU" )
		if use cycles-bin-kernels; then
			use cuda && CYCLES_TEST_DEVICES+=( "CUDA" )
			use optix && CYCLES_TEST_DEVICES+=( "OPTIX" )
		fi
		mycmakeargs+=(
			-DCMAKE_INSTALL_PREFIX_WITH_CONFIG="${T}"
			-DCYCLES_TEST_DEVICES="$(local IFS=";"; echo "${CYCLES_TEST_DEVICES[*]}")"
		)
	fi

	cmake_src_configure
}

src_test() {
	# A lot of tests needs to have access to the installed data files.
	# So install them into the image directory now.
	DESTDIR="${T}" cmake_build install

	blender_get_version
	# Define custom blender data/script file paths not be able to find them otherwise during testing.
	# (Because the data is in the image directory and it will default to look in /usr/share)
	export BLENDER_SYSTEM_RESOURCES="${T}/usr/share/blender/${BV}"

	# Sanity check that the script and datafile path is valid.
	# If they are not vaild, blender will fallback to the default path which is not what we want.
	[[ -d "$BLENDER_SYSTEM_RESOURCES" ]] || die "The custom resources path is invalid, fix the ebuild!"

	if use cuda; then
		cuda_add_sandbox -w
		addwrite "/dev/dri/renderD128"
		addwrite "/dev/char/"
	fi

	if use X; then
		xdg_environment_reset
	fi

	addwrite /dev/dri

	cmake_src_test

	# Clean up the image directory for src_install
	rm -fr "${T}/usr" || die
}

src_install() {
	blender_get_version

	# Pax mark blender for hardened support.
	pax-mark m "${BUILD_DIR}"/bin/blender

	cmake_src_install

	if use man; then
		# Slot the man page
		mv "${ED}/usr/share/man/man1/blender.1" "${ED}/usr/share/man/man1/blender-${BV}.1" || die
	fi

	if use doc; then
		# Define custom blender data/script file paths. Otherwise Blender will not be able to find them during doc building.
		# (Because the data is in the image directory and it will default to look in /usr/share)
		export BLENDER_SYSTEM_RESOURCES="${T}/usr/share/blender/${BV}"

		# Workaround for binary drivers.
		addpredict /dev/ati
		addpredict /dev/dri
		addpredict /dev/nvidiactl

		einfo "Generating Blender C/C++ API docs ..."
		cd "${CMAKE_USE_DIR}"/doc/doxygen || die
		doxygen -u Doxyfile || die
		doxygen || die "doxygen failed to build API docs."

		cd "${CMAKE_USE_DIR}" || die
		einfo "Generating (BPY) Blender Python API docs ..."
		"${BUILD_DIR}"/bin/blender --background --python doc/python_api/sphinx_doc_gen.py -noaudio || die "sphinx failed."

		cd "${CMAKE_USE_DIR}"/doc/python_api || die
		sphinx-build sphinx-in BPY_API || die "sphinx failed."

		docinto "html/API/python"
		dodoc -r "${CMAKE_USE_DIR}"/doc/python_api/BPY_API/.

		docinto "html/API/blender"
		dodoc -r "${CMAKE_USE_DIR}"/doc/doxygen/html/.
	fi

	# Fix doc installdir
	docinto html
	dodoc "${CMAKE_USE_DIR}"/release/text/readme.html
	rm -r "${ED}"/usr/share/doc/blender || die

	python_optimize "${ED}/usr/share/blender/${BV}/scripts"

	mv "${ED}/usr/bin/blender-thumbnailer" "${ED}/usr/bin/blender-${BV}-thumbnailer" || die "blender-thumbnailer version rename failed"
	mv "${ED}/usr/bin/blender" "${ED}/usr/bin/blender-${BV}" || die "blender version rename failed"
}

pkg_postinst() {
	elog
	elog "Blender uses python integration. As such, may have some"
	elog "inherent risks with running unknown python scripts."
	elog
	elog "It is recommended to change your blender temp directory"
	elog "from /tmp to /home/user/tmp or another tmp file under your"
	elog "home directory. This can be done by starting blender, then"
	elog "changing the 'Temporary Files' directory in Blender preferences."
	elog

	if use osl; then
		ewarn ""
		ewarn "OSL is know to cause runtime segfaults if Mesa has been linked to"
		ewarn "an other LLVM version than what OSL is linked to."
		ewarn "See https://bugs.gentoo.org/880671 for more details"
		ewarn ""
	fi

	if ! use python_single_target_python3_10; then
		elog "You are building Blender with a newer python version than"
		elog "supported by this version upstream."
		elog "If you experience breakages with e.g. plugins, please switch to"
		elog "python_single_target_python3_10 instead."
		elog "Bug: https://bugs.gentoo.org/737388"
		elog
	fi

	xdg_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_mimeinfo_database_update
	xdg_desktop_database_update

	ewarn ""
	ewarn "You may want to remove the following directory."
	ewarn "~/.config/${PN}/${BV}/cache/"
	ewarn "It may contain extra render kernels not tracked by portage"
	ewarn ""
}