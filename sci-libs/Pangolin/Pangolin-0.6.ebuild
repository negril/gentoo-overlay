# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )
inherit cmake python-r1

DESCRIPTION="A library for managing OpenGL display / interaction and abstracting video input."
HOMEPAGE="https://github.com/stevenlovegrove/Pangolin"

if [[ ${PV} == 9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/stevenlovegrove/Pangolin.git"
	EGIT_SUBMODULES=(
		'*'
		'-scripts/vcpkg'
		'-components/pango_python/pybind11'
	)
else
	SRC_URI="https://github.com/stevenlovegrove/Pangolin/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"

IUSE="+asan dc1394 examples +ffmpeg +jpeg +lz4 +openexr openni openni2 +png +python +raw +shared test +tiff tools +uvc +v4l wayland +X +zstd"
# IUSE_MISSING="depthsense realsense realsense2 pleora telicam"

RDEPEND="
	dc1394? ( media-libs/libdc1394 )
	ffmpeg? ( media-video/ffmpeg )
	jpeg? ( media-libs/libjpeg-turbo )
	lz4? ( app-arch/lz4 )
	openexr? ( media-libs/openexr )
	openni? ( dev-libs/OpenNI )
	openni2? ( dev-libs/OpenNI2 )
	png? ( media-libs/libpng )
	raw? ( media-libs/libraw )
	tiff? ( media-libs/tiff )
	uvc? ( media-libs/libuvc )
	zstd? ( app-arch/zstd )
	wayland? (
		dev-libs/wayland
		dev-libs/wayland-protocols
		x11-libs/libxkbcommon[wayland]
	)
	X? (
		x11-libs/libX11
		x11-libs/libxcb
	)
	media-libs/glew
	media-libs/libglvnd
"

DEPEND="
	dev-cpp/eigen
	${RDEPEND}
	python? (
		$(python_gen_any_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
		')
	)
	test? (
		=dev-cpp/catch-2*:0
	)
"

RDEPEND+="
	python? (
		${PYTHON_DEPS}
	)
"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
	|| ( X wayland )
"
RESTRICT="!test? ( test )"

src_configure() {
	local mycmakeargs=(
		-DBUILD_ASAN="$(usex asan)"
		-DBUILD_EXAMPLES="$(usex examples)"
		-DBUILD_PANGOLIN_DEPTHSENSE=OFF # "$(usex depthsense)"
		-DBUILD_PANGOLIN_FFMPEG="$(usex ffmpeg)"
		-DBUILD_PANGOLIN_LIBDC1394="$(usex dc1394)"
		-DBUILD_PANGOLIN_LIBJPEG="$(usex jpeg)"
		-DBUILD_PANGOLIN_LIBOPENEXR="$(usex openexr)"
		-DBUILD_PANGOLIN_LIBPNG="$(usex png)"
		-DBUILD_PANGOLIN_LIBRAW="$(usex raw)"
		-DBUILD_PANGOLIN_LIBTIFF="$(usex tiff)"
		-DBUILD_PANGOLIN_LIBUVC="$(usex uvc)"
		-DBUILD_PANGOLIN_LZ4="$(usex lz4)"
		-DBUILD_PANGOLIN_OPENNI="$(usex openni)"
		-DBUILD_PANGOLIN_OPENNI2="$(usex openni2)"
		-DBUILD_PANGOLIN_PLEORA=OFF # "$(usex pleora)"
		-DBUILD_PANGOLIN_PYTHON="$(usex python)"
		-DBUILD_PANGOLIN_REALSENSE=OFF # "$(usex realsense)"
		-DBUILD_PANGOLIN_REALSENSE2=OFF # "$(usex realsense2)"
		-DBUILD_PANGOLIN_V4L="$(usex v4l)"
		-DBUILD_PANGOLIN_TELICAM=OFF # "$(usex telicam)"
		-DBUILD_PANGOLIN_ZSTD="$(usex zstd)"
		-DBUILD_SHARED_LIBS="$(usex shared)"
		-DBUILD_TESTS="$(usex test)"
		-DBUILD_TOOLS="$(usex tools)"
	)

	if use python; then
		pangolin_configure() {
			local mycmakeargs=(
				"${mycmakeargs[@]}"
				-DPython_EXECUTABLE="${PYTHON}"
			)
			cmake_src_configure
		}

		python_foreach_impl pangolin_configure
	else
		cmake_src_configure
	fi
}

src_prepare() {
	cmake_src_prepare
	sed \
		-e 's#CMAKECONFIG_INSTALL_DIR lib/#CMAKECONFIG_INSTALL_DIR lib64/#g' \
		-e 's#DESTINATION lib#DESTINATION lib64#g' \
		-i \
			CMakeLists.txt || die
}

src_compile() {
	if use python; then
		pangolin_compile() {
			if [[ $(${PYTHON} -V) == $(python -V) ]]; then
				cmake_src_compile all
			else
				cmake_src_compile pypangolin
			fi
		}
		python_foreach_impl pangolin_compile
	else
		cmake_src_compile
	fi
}

src_test() {
	if use python; then
		python_foreach_impl cmake_src_test
	else
		cmake_src_test
	fi
}

src_install() {
	if use python; then
		pangolin_install() {
			if [[ $(${PYTHON} -V) == $(python -V) ]]; then
				cmake_src_install
			fi
			python_domodule "${BUILD_DIR}"/pypangolin-*.data/purelib/*
			python_domodule "${BUILD_DIR}"/pypangolin-*.dist-info
		}
		python_foreach_impl pangolin_install
	else
		cmake_src_install
	fi
	mkdir -p "${ED}/usr/share/doc/${PF}/"{NaturalSort,sigslot} || die
	mv "${ED}/usr/include/NaturalSort/"{LICENSE,README}".md" "${ED}/usr/share/doc/${PF}/NaturalSort/" || die
	mv "${ED}/usr/include/sigslot/"{LICENCE,README.md} "${ED}/usr/share/doc/${PF}/sigslot/" || die
	rm -r "${ED}/usr/include/dynalo/detail/"{macos,windows}"/" || die
}
