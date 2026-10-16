# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )

inherit cmake python-single-r1

DESCRIPTION="High level and feature rich audio library written in C++ with language bindings"
HOMEPAGE="
	https://audaspace.github.io/
	https://github.com/audaspace/audaspace
	https://github.com/neXyon/audaspace
"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/neXyon/audaspace.git"
else
	SRC_URI="
		https://github.com/audaspace/audaspace/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/neXyon/audaspace/commit/d6fbaa895108ad29c9c230f3721410e3722c92cf.patch
			-> ${PN}-1.9.0-gcc-17-include-string.patch
	"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="Apache-2.0"
SLOT="0/$(ver_cut 1-2)"

IUSE="
	+demos
	+jack +pipewire +pulseaudio
	+ffmpeg +sndfile +openal +sdl
	+doc +fftw +python +rubberband
"

# no tests
RESTRICT="test"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
"

DEPEND="
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/numpy[${PYTHON_USEDEP}]
		')
	)
	ffmpeg? (
		media-video/ffmpeg:=
	)
	fftw? (
		sci-libs/fftw:3.0=
	)
	jack? (
		virtual/jack
	)
	openal? (
		media-libs/openal
	)
	pulseaudio? (
		!pipewire? (
			media-libs/libpulse
		)
	)
	rubberband? (
		media-libs/rubberband:=
	)
	sdl? (
		media-libs/libsdl2
	)
	sndfile? (
		media-libs/libsndfile
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	doc? (
		app-text/doxygen
		python? (
			dev-python/sphinx
		)
	)
"

PATCHES=(
	"${DISTDIR}/${PN}-1.9.0-gcc-17-include-string.patch"
)

src_configure() {
	local mycmakeargs=(
		-DCMAKE_POLICY_DEFAULT_CMP0148="OLD" # FindPythonInterp

		-DBUILD_DEMOS="$(usex demos)"
		-DDOCUMENTATION_INSTALL_PATH="${EPREFIX}/usr/share/doc/${P}"
		-DSHARED_LIBRARY="yes"

		-DDYNLOAD_JACK="$(usex jack)"
		-DDYNLOAD_PIPEWIRE="$(usex pipewire)"
		-DDYNLOAD_PULSEAUDIO="$(usex pulseaudio "$(usex !pipewire)")"

		-DPLUGIN_FFMPEG="$(usex ffmpeg)"
		-DPLUGIN_JACK="$(usex jack)"
		-DPLUGIN_LIBSNDFILE="$(usex sndfile)"
		-DPLUGIN_OPENAL="$(usex openal)"
		-DPLUGIN_PIPEWIRE="$(usex pipewire)"
		-DPLUGIN_PULSEAUDIO="$(usex pulseaudio "$(usex !pipewire)")"
		-DPLUGIN_SDL="$(usex sdl)"

		-DWITH_BINDING_DOCS="$(usex doc)"
		-DWITH_C="no"
		-DWITH_DOCS="$(usex doc)"
		-DWITH_FFMPEG="$(usex ffmpeg)"
		-DWITH_FFTW="$(usex fftw)"
		-DWITH_JACK="$(usex jack)"
		-DWITH_LIBSNDFILE="$(usex sndfile)"
		-DWITH_OPENAL="$(usex openal)"
		-DWITH_PIPEWIRE="$(usex pipewire)"
		-DWITH_PULSEAUDIO="$(usex pulseaudio "$(usex !pipewire)")"
		-DWITH_PYTHON="$(usex python)"
		-DWITH_PYTHON_MODULE="no"
		-DWITH_RUBBERBAND="$(usex rubberband)"
		-DWITH_SDL="$(usex sdl)"

		-DWITH_STRICT_DEPENDENCIES="yes"
		-DWITH_VERSIONED_PLUGINS="yes"
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	insinto /etc/ld.so.conf.d
	newins - 99-${PN}.conf <<-EOF
		/usr/share/audaspace/plugins
	EOF
}
