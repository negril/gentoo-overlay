# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# The swig fork is required for compatibility with both provided and
# 3rd-party Python scripts. Required patch was sent to upstream in
# 2014: https://github.com/swig/swig/pull/251
SWIG_PV=7
SWIG_P="swig-${PN}-${SWIG_PV}"

AUTOTOOLS_AUTO_DEPEND="no"
DOCS_BUILDER="sphinx"
DOCS_DIR="docs"
PYTHON_COMPAT=( python3_{12..14} )
inherit autotools cmake-multilib flag-o-matic optfeature python-single-r1 docs qmake-utils verify-sig xdg

DESCRIPTION="A stand-alone graphics debugging tool"
HOMEPAGE="https://renderdoc.org https://github.com/baldurk/renderdoc"
SRC_URI="
	https://github.com/baldurk/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	gui? (
		https://github.com/baldurk/swig/archive/${PN}-modified-${SWIG_PV}.tar.gz -> ${SWIG_P}.tar.gz
	)
	verify-sig? (
		https://github.com/baldurk/renderdoc/releases/download/v${PV}/v${PV}.tar.gz.asc -> ${P}.tar.gz.asc
	)
"

# renderdoc: MIT
#   + cmdline: BSD (not compatible with upstream lib)
#   + farm fresh icons: CC-BY-3.0
#   + half: MIT (not compatible with system dev-libs/half)
#   + include-bin ZLIB (upstream doesn't exist anymore, maintained in tree)
#   + md5: public-domain
#   + plthook: BSD-2
#   + pugixml: MIT
#   + radeon gpu analyzer: MIT
#   + source code pro: OFL-1.1
#   + stb: public-domain
#   + tinyfiledialogs: ZLIB
#   + glslang: BSD
#   + docs? ( sphinx.paramlinks: MIT )
# swig: GPL-3+ BSD BSD-2
LICENSE="BSD BSD-2 CC-BY-3.0 GPL-3+ MIT OFL-1.1 public-domain ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"
IUSE="gui"
REQUIRED_USE="
	doc? ( gui )
	gui? ( ${PYTHON_REQUIRED_USE} )
"

RDEPEND="
	gui? ( ${PYTHON_DEPS} )
	app-arch/lz4:=[${MULTILIB_USEDEP}]
	app-arch/zstd:=[${MULTILIB_USEDEP}]
	dev-libs/miniz:=[${MULTILIB_USEDEP}]
	x11-libs/libX11[${MULTILIB_USEDEP}]
	x11-libs/libxcb:=[${MULTILIB_USEDEP}]
	x11-libs/xcb-util-keysyms[${MULTILIB_USEDEP}]
	virtual/opengl[${MULTILIB_USEDEP}]
	dev-util/glslang[${MULTILIB_USEDEP}]
	gui? (
		${PYTHON_DEPS}
		dev-qt/qtbase:6[gui,network,ssl,widgets]
		dev-qt/qtsvg:6
	)
"
DEPEND="${RDEPEND}"
# qtbase provides qmake, which is required to build the qrenderdoc gui.
BDEPEND="
	x11-base/xorg-proto
	virtual/pkgconfig
	gui? (
		${AUTOTOOLS_DEPEND}
		${PYTHON_DEPS}
		dev-libs/libpcre
		dev-qt/qtbase:6
		app-alternatives/yacc
	)
	verify-sig? ( sec-keys/openpgp-keys-baldurkarlsson )
"

PATCHES=(
	# The analytics seem very reasonable, and even without this patch they are NOT sent before the user accepts.
	# But default the selection to off, just in case.
	"${FILESDIR}/${PN}-1.18-analytics-off.patch"

	# Only search for PySide2 if pyside2 USE flag is set.
	# Bug #833627
	"${FILESDIR}/${PN}-1.18-conditional-pyside.patch"

	# Pass CXXFLAGS and LDFLAGS through to qmake when qrenderdoc is built.
	"${FILESDIR}/${PN}-1.18-system-flags.patch"

	# Needed to prevent sandbox violations during build.
	"${FILESDIR}/${PN}-1.27-env-home.patch"

	"${FILESDIR}/${PN}-1.30-r1-system-compress.patch"

	# Bug #925578
	"${FILESDIR}/${PN}-1.31-lld.patch"

	"${FILESDIR}/${PN}-1.36-gcc15-fix.patch"

	# add -DINSTALL_SHARED_FILES
	"${FILESDIR}/${PN}-1.39-multilib-install.patch"

	# modify ICD layer name with ABI
	"${FILESDIR}/${PN}-1.39-icd.patch"
)

DOCS=(
	util/LINUX_DIST_README
)

VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/openpgp-keys/baldurkarlsson.gpg"

pkg_setup() {
	use gui && python-single-r1_pkg_setup

	MULTILIB_CHOST_TOOLS=(
		/usr/bin/renderdoccmd
	)
}

src_unpack() {
	if use verify-sig; then
		verify-sig_verify_detached "${DISTDIR}/${P}.tar.gz"{,.asc}
	fi

	# Do not unpack the swig sources here. CMake will do that if required.
	unpack "${P}.tar.gz"
}

src_prepare() {
	cmake_src_prepare

	# Remove the calls to install the documentation files. Instead, install them with einstalldocs.
	sed \
		-e '/share\/doc\/renderdoc/d' \
		-i \
			CMakeLists.txt \
			qrenderdoc/CMakeLists.txt \
		|| die 'sed remove doc install failed'

	# Assumes that the build directory is "${S}"/build, which it is not.
	sed \
		-e "s|../build/lib|${BUILD_DIR}/lib|" \
		-i \
			docs/conf.py \
		|| die 'sed patch doc sys.path failed'

	# Bug #836235
	sed \
		-e '/#include <stdarg/i #include <time.h>' \
		-i \
			renderdoc/os/os_specific.h \
		|| die 'sed include time.h failed'

	sed \
		-e '/QT += x11extras/d' \
		-i \
			qrenderdoc/qrenderdoc.pro \
		|| die 'sed QT += x11extras failed'
}

multilib_src_configure() {
	# Lots of type mismatch issues.
	filter-lto

	local mycmakeargs=(
		# Build system does not know that this is a tagged release, as we just have the tarball and not the git repository.
		-DBUILD_VERSION_STABLE=ON

		-DENABLE_PYRENDERDOC="$(multilib_native_usex gui)"
		-DENABLE_QRENDERDOC="$(multilib_native_usex gui)"

		-DENABLE_VULKAN=ON
		-DENABLE_EGL=ON
		-DENABLE_GL=ON
		-DENABLE_GLES=ON

		-DENABLE_XCB=ON
		-DENABLE_XLIB=ON

		# Upstream says that this option is unsupported and should not be used yet.
		-DENABLE_UNSUPPORTED_EXPERIMENTAL_POSSIBLY_BROKEN_WAYLAND=OFF

		# renderdoc_capture.json is installed here
		-DVULKAN_LAYER_FOLDER="${EPREFIX}/etc/vulkan/implicit_layer.d"
	)

	if multilib_is_native_abi; then
		mycmakeargs+=(
			-DINSTALL_SHARED_FILES=ON
		)

		use gui && mycmakeargs+=(
			-DPython3_EXECUTABLE="${PYTHON}"
			-DRENDERDOC_SWIG_PACKAGE="${DISTDIR}/${SWIG_P}.tar.gz"

			# Needed after qtchooser removal, bug #836474.
			-DQMAKE_QT5_COMMAND="$(qt6_get_bindir)/qmake"

			# Bug #926549
			-DQRENDERDOC_ENABLE_PYSIDE2=OFF
		)
	else
		mycmakeargs+=(
			-DVULKAN_JSON_SUFFIX="_${MULTILIB_ABI_FLAG}"
			-DVULKAN_LAYER_NAME="VK_LAYER_RENDERDOC_Capture_${MULTILIB_ABI_FLAG}"
		)
	fi

	cmake_src_configure
}

multilib_src_install_all() {
	docs_compile
	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst
	optfeature "android remote contexts" dev-util/android-tools
	optfeature "vulkan contexts" media-libs/vulkan-loader
	optfeature "spirv-dis" dev-util/spirv-tools
	optfeature "spirv-cross" dev-util/spirv-cross
	optfeature "dxc" dev-util/DirectXShaderCompiler
}
