# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
inherit cmake flag-o-matic optfeature python-any-r1 xdg

DESCRIPTION="The Programmers Solid 3D CAD Modeller"
HOMEPAGE="https://openscad.org/"

if [[ ${PV} = *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/openscad/openscad.git"
	EGIT_SUBMODULES=(
		'*'
		'-mimalloc'
		'-submodules/manifold'
		'-OpenCSG'
	)
else
	if [[ ${PV} = *pre* ]] ; then
		COMMIT="756e080c7e49072d9926cf9ce766def180a0dcae"
		SANITIZERS_CMAKE_COMMIT="0573e2ea8651b9bb3083f193c41eb086497cc80a"
		MCAD_COMMIT="bd0a7ba3f042bfbced5ca1894b236cea08904e26"

		SRC_URI="
			https://github.com/openscad/openscad/archive/${COMMIT}.tar.gz
				-> ${P}.tar.gz
			https://github.com/arsenm/sanitizers-cmake/archive/${SANITIZERS_CMAKE_COMMIT}.tar.gz
				-> sanitizers-cmake-${SANITIZERS_CMAKE_COMMIT}.tar.gz
			test? (
				https://github.com/openscad/MCAD/archive/${MCAD_COMMIT}.tar.gz -> ${PN}-MCAD-${MCAD_COMMIT}.tar.gz
			)
		"
		# doc downloads are not versioned and found at:
		# https://files.openscad.org/documentation/
		S="${WORKDIR}/${PN}-${COMMIT}"
	else
		SRC_URI="https://github.com/${PN}/${PN}/releases/download/${P}/${P}.src.tar.gz -> ${P}.tar.gz"
	fi
	KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"
fi

# Code is GPL-3+, MCAD library is LGPL-2.1
LICENSE="GPL-3+ LGPL-2.1"
SLOT="0"

IUSE="cgal dbus +egl experimental glx +gui hidapi +manifold mimalloc pdf spacenav test"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	|| ( cgal manifold )
	dbus? ( gui )
	hidapi? ( gui )
	spacenav? ( gui )
	|| ( egl glx )
"

RDEPEND="
	dev-libs/boost:=
	dev-libs/double-conversion:=
	dev-libs/glib:2
	dev-libs/libxml2
	dev-libs/libzip:=
	media-gfx/opencsg
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz:=
	media-libs/lib3mf:=
	cgal? (
		sci-mathematics/cgal:=
	)
	sci-mathematics/clipper2
	media-libs/libglvnd
	glx? (
		media-libs/libglvnd[X]
	)
	gui? (
		dev-qt/qt5compat:6
		dev-qt/qtbase:6[concurrent,dbus?,network,opengl,widgets]
		dev-qt/qtmultimedia:6
		dev-qt/qtsvg:6
		x11-libs/qscintilla:=[qt6]
	)
	hidapi? ( dev-libs/hidapi )
	manifold? (
		dev-cpp/tbb
		>=sci-mathematics/manifold-3.0.1
	)
	mimalloc? ( dev-libs/mimalloc:= )
	pdf? ( x11-libs/cairo )
	spacenav? ( dev-libs/libspnav )
"
DEPEND="
	${RDEPEND}
	dev-cpp/eigen:3=
"
BDEPEND="
	app-alternatives/yacc
	app-alternatives/lex
	dev-util/itstool
	sys-devel/gettext
	virtual/pkgconfig
	test? (
		$(python_gen_any_dep '
			dev-python/numpy[${PYTHON_USEDEP}]
			dev-python/pillow[${PYTHON_USEDEP}]
			dev-python/pip[${PYTHON_USEDEP}]
		')
		|| (
			gui-wm/tinywl
			<gui-libs/wlroots-0.17.3[tinywl(-)]
		)
	)
"

DOCS=(
	README.md
	RELEASE_NOTES.md
	doc/contributor_copyright.txt
	doc/hacking.md
	doc/testing.txt
	doc/translation.txt
)

# NOTE the build system sets up a venv for tests, we could use imagemagick with -DUSE_IMAGE_COMPARE_PY="no"
python_check_deps() {
	python_has_version "dev-python/numpy[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/pillow[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/pip[${PYTHON_USEDEP}]"
}

pkg_setup() {
	use test && python-any-r1_pkg_setup
}

src_prepare() {
	if use test && [[ ${PV} != *9999* ]] ; then
		mv -f "${WORKDIR}/MCAD-${MCAD_COMMIT}"/* "${S}/libraries/MCAD/" || die
	fi

	# NOTE adhere CMP0167
	# https://cmake.org/cmake/help/latest/policy/CMP0167.html
	sed \
		-e '/find_package(Boost/s/)/ CONFIG)/g' \
		-i CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	# -Werror=odr
	# https://github.com/openscad/openscad/issues/5239
	filter-lto

	local mycmakeargs=(
		-DCLANG_TIDY="no"
		-DENABLE_CAIRO="$(usex pdf)"
		-DENABLE_CGAL="$(usex cgal)"
		-DENABLE_EGL="$(usex egl)"
		-DENABLE_GLX="$(usex glx)"
		-DENABLE_MANIFOLD="$(usex manifold)"
		-DENABLE_PYTHON="no"
		-DENABLE_TESTS="$(usex test)"

		-DEXPERIMENTAL="$(usex experimental)"

		-DHEADLESS="$(usex !gui)"
		-DUSE_BUILTIN_CLIPPER2="no"
		-DUSE_BUILTIN_MANIFOLD="no"
		-DUSE_CCACHE="no"
		-DUSE_GLAD="yes"
		-DUSE_GLEW="no"
		-DUSE_MIMALLOC="$(usex mimalloc)"
		-DUSE_QT6="$(usex gui)"
		-DOFFLINE_DOCS="no" # TODO
		-DOPENCSG_DIR="${EPREFIX}/usr/$(get_libdir)"
	)

	if use gui; then
		mycmakeargs+=(
			-DENABLE_HIDAPI="$(usex hidapi)"
			-DENABLE_QTDBUS="$(usex dbus)"
			-DENABLE_SPNAV="$(usex spacenav)"
		)
	fi

	if [[ ${PV} != *9999* ]] ; then
		mycmakeargs+=(
			-DCMAKE_MODULE_PATH="${WORKDIR}/sanitizers-cmake-${SANITIZERS_CMAKE_COMMIT}/cmake"
		)
		if [[ ${PV} = *pre* ]] ; then
			mycmakeargs+=(
				-DOPENSCAD_COMMIT="${COMMIT:0:9}"
				-DOPENSCAD_VERSION="$(ver_cut 1-3)"
				-DSNAPSHOT="yes"
			)
		fi
	else
		mycmakeargs+=(
			-DOPENSCAD_COMMIT="${COMMIT:0:9}"
			-DSNAPSHOT="yes"
		)
	fi

	cmake_src_configure
}

hardware_add_gpu_sandbox() {
	local dris cards PREDICT=() WRITE=()

	# mesa will make use of udmabuf if it exists
	if [[ -c "/dev/udmabuf" ]]; then
		WRITE+=(
			"/dev/udmabuf"
		)
	fi

	# /dev/dri/card[%d]
	# /dev/dri/renderD[128+%d]
	readarray -t dris <<<"$(
		find /sys/class/drm/*/device/drm \
			-mindepth 1 -maxdepth 1 -type d -exec basename {} \; \
			| sort | uniq | sed 's:^:/dev/dri/:'
	)"

	[[ -n "${dris[*]}" ]] && WRITE+=( "${dris[@]}" )

	if [[ -d /sys/module/nvidia ]]; then
		stat --printf="%Hr:%Lr"
		PREDICT+=(
			# /dev/char/195:X   # ../nvidiaX
			# /dev/char/195:254 # ../nvidia-modeset
			# /dev/char/195:255 # ../nvidiactl
			/dev/char/
		)

		# /dev/nvidia{0-9}
		readarray -t nvidia_devs <<<"$(
			find /dev -regextype posix-extended  -regex '/dev/nvidia(|-(nvswitch|vgpu))[0-9]*'
		)"
		[[ -n "${nvidia_devs[*]}" ]] && WRITE+=( "${nvidia_devs[@]}" )

		WRITE+=(
			"/dev/nvidiactl"
			# "/dev/nvidia-caps/nvidia-cap%d"
			"/dev/nvidia-caps/"

			# "/dev/nvidia-caps-imex-channels/channel%d"
			"/dev/nvidia-caps-imex-channels/"

			"/dev/nvidia-modeset"

			"/dev/nvidia-nvlink"
			"/dev/nvidia-nvswitchctl"

			"/dev/nvidia-uvm"
			"/dev/nvidia-uvm-tools"

			"/dev/nvidia-vgpuctl"
		)
	fi

	WRITE+=(
		# for portage
		"/proc/self/task/"
	)

	eqawarn "SANDBOX_WRITE   ${SANDBOX_WRITE//:/ }"
	eqawarn "SANDBOX_PREDICT ${SANDBOX_PREDICT//:/ }"

	local dev
	for dev in "${WRITE[@]}"; do
		if [[ ! -e "${dev}" ]]; then
			eqawarn "${dev} does not exist"
			continue
		fi

		if [[ -w "${dev}" ]]; then
			eqawarn "${dev} is already writable"
			continue
		fi

		eqawarn "${dev} addwrite"
		addwrite "${dev}"

		if [[ ! -d "${dev}" ]] && [[ ! -w "${dev}" ]]; then
			eerror "can not access ${dev} after addwrite"
		fi
	done

	local dev
	for dev in "${PREDICT[@]}"; do
		if [[ ! -e "${dev}" ]]; then
			eqawarn "${dev} does not exist"
			continue
		fi

		eqawarn "${dev} addpredict"
		addpredict "${dev}"
	done

	eqawarn "SANDBOX_WRITE   ${SANDBOX_WRITE//:/ }"
	eqawarn "SANDBOX_PREDICT ${SANDBOX_PREDICT//:/ }"
}

virtwl() {
	debug-print-function "${FUNCNAME[0]}" "$@"

	[[ $# -lt 1 ]] && die "${FUNCNAME[0]} needs at least one argument"

	# [[ -n $XDG_RUNTIME_DIR ]] || die "${FUNCNAME[0]} needs XDG_RUNTIME_DIR to be set; try xdg_environment_reset"

	tinywl -h >/dev/null || die 'tinywl -h failed'

	local VIRTWL VIRTWL_PID
	coproc VIRTWL { WLR_BACKENDS=headless exec tinywl -s 'echo $WAYLAND_DISPLAY; read _; kill $PPID'; }
	local -x WAYLAND_DISPLAY
	read -r WAYLAND_DISPLAY <&"${VIRTWL[0]}"

	debug-print "${FUNCNAME[0]}: $*"
	nonfatal "$@"
	local r=$?

	[[ -n $VIRTWL_PID ]] || die "tinywl exited unexpectedly"
	exec {VIRTWL[0]}<&- {VIRTWL[1]}>&-
	return "$r"
}

src_test() {
	# xdg_environment_reset

	hardware_add_gpu_sandbox

	sed \
		-e "s/OPENSCAD_BINARY/OPENSCADPATH/g" \
		-i tests/test_cmdline_tool.py || die

	cd "${BUILD_DIR}" || die

	# NOTE link in from CMAKE_USE_DIR
	ln -s "${CMAKE_USE_DIR}/color-schemes" . || die
	ln -s "${CMAKE_USE_DIR}/locale" . || die
	ln -s "${CMAKE_USE_DIR}/shaders" . || die

	virtwl cmake_src_test -j1
}

src_install() {
	DOCS+=( doc/*.pdf )

	cmake_src_install

	mv -i "${ED}"/usr/share/openscad/locale "${ED}"/usr/share || die "failed to move locales"
	dosym -r /usr/share/locale /usr/share/openscad/locale
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "support scad major mode in GNU Emacs" app-emacs/scad-mode
}
