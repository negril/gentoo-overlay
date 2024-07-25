# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit pax-utils unpacker xdg
DESCRIPTION="cross-platform Git client"
HOMEPAGE="https://www.gitkraken.com"
SRC_URI="https://release.axocdn.com/linux/GitKraken-v${PV}.deb"
S="${WORKDIR}"

LICENSE="Axosoft"
SLOT="0"
KEYWORDS="~amd64"

IUSE="system-chromium system-ffmpeg"

RESTRICT="bindist mirror test strip"

RDEPEND="
	>=net-print/cups-1.7.0
	>=x11-libs/cairo-1.6.0
	>=media-libs/fontconfig-2.11
	media-sound/alsa-utils
	app-accessibility/at-spi2-core
	>=sys-apps/dbus-1.9.14
	>=x11-libs/libdrm-2.4.38
	>=dev-libs/expat-2.0.1
	>=x11-libs/gtk+-3.9.10
	>=dev-libs/nss-3.22
	>=x11-libs/pango-1.14.0
	>=x11-libs/libX11-1.4.99.1
	>=x11-libs/libxcb-1.9.2
	>=x11-libs/libXcomposite-0.3
	>=x11-libs/libXdamage-1.1
	x11-libs/libXext
	x11-libs/libXfixes
	>=x11-libs/libxkbcommon-0.5.0
	x11-libs/libXrandr
	dev-libs/libgcrypt
	x11-libs/libnotify
	x11-libs/libXtst
	x11-libs/libxkbfile
	dev-libs/glib
	x11-misc/xdg-utils

	system-chromium? (
		www-client/chromium
	)
	system-ffmpeg? (
		media-video/ffmpeg[chromium]
	)
"

QA_PREBUILT="*"

src_prepare() {
	SYSTEMLIBS=(
		usr/share/gitkraken/libEGL.so
		usr/share/gitkraken/libGLESv2.so
		usr/share/gitkraken/libvulkan.so.1
		# TODO https://github.com/google/swiftshader
		# usr/share/gitkraken/libvk_swiftshader.so
		# usr/share/gitkraken/vk_swiftshader_icd.json
	)

	local FILES=(
		usr/share/gitkraken/resources/app.asar.unpacked/git
		usr/share/gitkraken/resources/app.asar.unpacked/resources/cli/win
	)

	if use system-chromium; then
		FILES+=(
			# www-client/chromium
			usr/share/gitkraken/chrome_100_percent.pak
			usr/share/gitkraken/chrome_200_percent.pak
			usr/share/gitkraken/chrome_crashpad_handler
			usr/share/gitkraken/chrome-sandbox
			usr/share/gitkraken/LICENSE.electron
			usr/share/gitkraken/LICENSES.chromium.html
		)
	fi

	if use system-ffmpeg; then
		SYSTEMLIBS+=(
			# media-video/ffmpeg[chromium]
			usr/share/gitkraken/libffmpeg.so
		)
	fi

	FILES+=(
		"${SYSTEMLIBS[@]}"
	)

	rm -Rf "${FILES[@]}" || die
}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	insinto /usr/bin
	doins usr/bin/gitkraken

	insinto /usr/share
	doins -r usr/share/{gitkraken,applications,pixmaps,lintian}

	dodoc usr/share/doc/gitkraken/copyright

	local EXEFILES NODEFILES
	EXEFILES=(
		/usr/share/gitkraken/gitkraken
		/usr/share/gitkraken/libvk_swiftshader.so
		/usr/share/gitkraken/resources/app.asar.unpacked/node_modules/@axosoft/node-spawn-server/target/release/node-spawn-server
		/usr/share/gitkraken/resources/app.asar.unpacked/node_modules/@axosoft/rust-socket-bridge/target/release/rust-socket-bridge
		/usr/share/gitkraken/resources/app.asar.unpacked/resources/cli/unix/gkc
		/usr/share/gitkraken/resources/app.asar.unpacked/resources/hooks/hook.template
		/usr/share/gitkraken/resources/app.asar.unpacked/src/js/redux/domain/AskPass/AskPass.sh
		/usr/share/gitkraken/resources/app.asar.unpacked/src/js/redux/domain/Rebase/GitSequenceEditor.sh
		/usr/share/gitkraken/resources/bin/gitkraken.sh
		/usr/share/lintian/overrides/gitkraken
	)

	readarray -t NODEFILES <<<"$(find usr/share/gitkraken/resources/app.asar.unpacked/node_modules/ -name '*.node' )"

	if ! use system-chromium; then
		EXEFILES+=(
			/usr/share/gitkraken/chrome_crashpad_handler
			/usr/share/gitkraken/chrome-sandbox
		)
		fperms u+s /usr/share/gitkraken/chrome-sandbox
		pax-mark m usr/share/gitkraken/chrome-sandbox
	fi

	if ! use system-ffmpeg; then
		EXEFILES+=(
			/usr/share/gitkraken/libffmpeg.so
		)
	fi

	fperms +x "${EXEFILES[@]}" "${NODEFILES[@]}"
	pax-mark m usr/share/gitkraken/gitkraken

	if [[ $(find "${S}" -type f -executable -ls | wc -l) -ne $(( ${#EXEFILES[@]} + ${#NODEFILES[@]} )) ]]; then
		eqawarn "incomplete EXEFILES"
	fi

	for lib in "${SYSTEMLIBS[@]}"; do
		dosym -r "/usr/lib64/$(basename "${lib}")" "${lib}"
	done
}

pkg_postinst() {
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
}
