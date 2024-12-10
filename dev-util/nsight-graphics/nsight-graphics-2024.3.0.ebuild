# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker

DESCRIPTION="standalone developer tool with ray-tracing support"
HOMEPAGE="https://developer.nvidia.com/nsight-graphics"

MY_PV="$(ver_rs 1-3 '_')"
PV_LONG="${PV}.24333"

SRC_URI="
	https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/linux/NVIDIA_Nsight_Graphics_${PV_LONG}.run
	https://developer.download.nvidia.com/images/nvidia-nsight-graphics-icon-gbp-shaded-128.png
		-> nvidia-nsight-graphics-icon-${PV}.png
"

S="${WORKDIR}/pkg"

LICENSE="NVIDIA-r2"
SLOT="$(ver_cut 1-2)"
KEYWORDS="~amd64"

RESTRICT="bindist mirror strip test"

RDEPEND="
	dev-libs/openssl
	dev-qt/qtbase:6
	dev-qt/qtcharts:6
	dev-qt/qtdeclarative:6
	dev-qt/qtsvg:6
	dev-util/breakpad
	media-libs/libglvnd
	net-libs/libssh
	x11-libs/libX11
	x11-libs/libxkbcommon
	x11-drivers/nvidia-drivers
	sys-apps/util-linux
"

BDEPEND="
	dev-util/patchelf
"

src_prepare() {
	rm EULA.txt || die

	pushd host/linux-desktop-nomad-x64 &>/dev/null || die

	local libs=(
		# core2md

		# libboost_context.so
		# libboost_context.so.1.78.0 # dev-libs/boost[context]

		libcrypto.so
		libcrypto.so.3

		libfreetype.so.6

		libicudata.so.71
		libicui18n.so.71
		libicuuc.so.71

		libQt6Charts.so.6
		libQt6Concurrent.so.6
		libQt6Core.so.6
		libQt6DBus.so.6
		libQt6Gui.so.6
		libQt6Network.so.6
		libQt6OpenGL.so.6
		libQt6OpenGLWidgets.so.6
		libQt6PrintSupport.so.6
		libQt6Qml.so.6
		libQt6Sql.so.6
		libQt6StateMachine.so.6
		libQt6Svg.so.6
		libQt6SvgWidgets.so.6
		libQt6Test.so.6
		libQt6Widgets.so.6
		libQt6XcbQpa.so.6
		libQt6Xml.so.6

		libssh.so

		libssl.so
		libssl.so.3

		libstdc++.so.6

		libzstd.so.1
	)

	for lib in "${libs[@]}"; do
		find . -name "${lib}" -delete
	done

# 	rm -r \
# 		resources \
# 		translations \
# 		|| die

	rm -r \
		libexec \
		Plugins/imageformats \
		Plugins/platforms \
		Plugins/tls \
		Plugins/wayland-decoration-client \
		Plugins/wayland-graphics-integration-client \
		Plugins/wayland-shell-integration \
		Plugins/xcbglintegrations \
		|| die

	readarray -t rpath_bins < <(find . -maxdepth 1 -name '*.bin')
	for rpath_bin in "${rpath_bins[@]}"; do
		ebegin "fixing rpath for ${rpath_bin}"
		patchelf --set-rpath '$ORIGIN' "${rpath_bin}" || die
		eend $?

		sed \
			-e "2i export QT_PLUGIN_PATH=\"${EPREFIX}/usr/lib64/qt6/plugins\"" \
			-e "s/NV_AGORA_PATH/NV_AGORA_PATH_/g" \
			-i "$(basename "${rpath_bin}" .bin)" \
			|| die
	done

	popd &>/dev/null || die

	eapply_user
}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	local dir
	dir="/opt/NVIDIA-Nsight-Graphics-$(ver_cut 1-2)"

	dodir "${dir}"
	cp -a ./* "${ED}${dir}" || die

	cp "${DISTDIR}/nvidia-nsight-graphics-icon-${PV}.png" "${ED}${dir}/host/linux-desktop-nomad-x64/ngfx-ui.png" || die

	newmenu - "${P}.desktop" <<-EOF || die
		[Desktop Entry]
		Type=Application
		Name=Nsight Graphics ${PV}
		GenericName=Nsight Graphics
		Icon=${EPREFIX}${dir}/host/linux-desktop-nomad-x64/ngfx-ui.png
		Exec=env WAYLAND_DISPLAY= ${EPREFIX}${dir}/host/linux-desktop-nomad-x64/ngfx-ui
		TryExec=${EPREFIX}${dir}/host/linux-desktop-nomad-x64/ngfx-ui
		Keywords=cuda;gpu;nvidia;nsight;
		X-AppInstall-Keywords=cuda;gpu;nvidia;nsight;
		X-GNOME-Keywords=cuda;gpu;nvidia;nsight;
		Terminal=No
		Categories=Development;Profiling;ParallelComputing
	EOF
}
