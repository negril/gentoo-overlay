# Copyright 1999-2025 Gentoo Foundation
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

IUSE="system-chromium +system-ffmpeg"

RESTRICT="bindist mirror test strip"

RDEPEND="
	app-accessibility/at-spi2-core:2
	app-crypt/mit-krb5
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nss
	media-sound/alsa-utils
	net-print/cups
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxkbfile
	x11-libs/pango
	x11-misc/xdg-utils
	dev-libs/nspr
	dev-libs/openssl
	system-chromium? (
		www-client/chromium
	)
	system-ffmpeg? (
		media-video/ffmpeg[chromium(-)]
	)
"

QA_PREBUILT="*"

src_prepare() {
	eapply_user

	SYSTEMLIBS=(
		usr/share/gitkraken/libEGL.so
		usr/share/gitkraken/libGLESv2.so
		usr/share/gitkraken/libvulkan.so.1
		# TODO https://github.com/google/swiftshader
		# usr/share/gitkraken/libvk_swiftshader.so
		# usr/share/gitkraken/vk_swiftshader_icd.json
	)

	rm -R "${SYSTEMLIBS[@]}" || die

	readarray -t NODEFILES < <(
		find usr/share/gitkraken/resources/app.asar.unpacked/node_modules/ -executable -name '*.node' -printf '/%p\n'
	)

	if [[ -n "${NODEFILES[*]}" ]]; then
		fperms +x "${NODEFILES[@]}"
	fi
	unset NODEFILES

	if use system-ffmpeg; then
		# media-video/ffmpeg[chromium]
		rm usr/share/gitkraken/libffmpeg.so || die
	fi

	sed -i \
		-e '/^Exec/s/$/ --ozone-platform-hint=auto/' \
		-e '/^StartupWMClass/s/gitkraken/GitKraken/g' \
		usr/share/applications/*.desktop \
		|| die

	mv "usr/share/doc/${PN}" "usr/share/doc/${P}" || die

	rm usr/share/gitkraken/resources/app.asar.unpacked/node_modules/@axosoft/nodegit/build/Release/*ubuntu-*.node || die

	if ! use elibc_glibc; then
		rm usr/share/gitkraken/resources/app.asar.unpacked/node_modules/@msgpackr-extract/msgpackr-extract-linux-x64/*glibc.node || die
	fi
	if ! use elibc_musl; then
		rm usr/share/gitkraken/resources/app.asar.unpacked/node_modules/@msgpackr-extract/msgpackr-extract-linux-x64/*musl.node || die
	fi

}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	mv ./* "${ED}" || die "mv failed"

	if ! use system-chromium; then
		fperms u+s /usr/share/gitkraken/chrome-sandbox
		pax-mark m "${ED}/usr/share/gitkraken/chrome-sandbox"
	fi

	pax-mark m "${ED}/usr/share/gitkraken/gitkraken"

	for lib in "${SYSTEMLIBS[@]}"; do
		dosym -r "/usr/$(get_libdir)/$(basename "${lib}")" "${lib}"
	done

	if use system-ffmpeg; then
		dosym -r "/usr/$(get_libdir)/chromium/libffmpeg.so" "usr/share/gitkraken/libffmpeg.so"
	fi
}
