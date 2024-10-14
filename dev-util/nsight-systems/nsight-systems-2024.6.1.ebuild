# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker

DESCRIPTION=""
HOMEPAGE="https://developer.nvidia.com/nsight-systems"

MY_PV=$(ver_cut 1-2)
MY_PV=${MY_PV/./_}

PV_LONG="2024.6.1.90-3490548"
PV_SHORT="2024.6.1.90-1"

SRC_URI="
	amd64? (
		cli? (
			https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/NsightSystems-linux-cli-public-${PV_LONG}.deb
		)
		!cli? (
			https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/${PN}-${PV}_${PV_SHORT}_amd64.deb
		)
	)
	arm64? (
		cli? (
			https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/${PN}-cli-${PV}_${PV_SHORT}_arm64.deb
		)
		!cli? (
			https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/${PN}-${PV}_${PV_SHORT}_arm64.deb
		)
	)
"
# 			https://developer.nvidia.com/downloads/assets/tools/secure/${PN}/${MY_PV}/NsightSystems-linux-public-${PV_SHORT}.run
S="${WORKDIR}"

LICENSE="NVIDIA-r2"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

IUSE="cli"
RESTRICT="bindist mirror strip test"

DEPEND=""
RDEPEND="${DEPEND}
	dev-qt/qtwayland:6
	media-libs/gst-plugins-base:1.0
	dev-libs/nss
	virtual/krb5
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXtst
	x11-libs/libxkbfile
	x11-libs/libxshmfence
	sys-cluster/rdma-core
"
# 	dev-libs/wayland
# 	dev-libs/glib
# 	x11-libs/libX11
# 	x11-libs/libxkbcommon
# 	media-libs/fontconfig
# "
BDEPEND="
	dev-util/patchelf
"

src_prepare() {
	if use cli ; then
		rmdir usr || die
	else
		sed -e "s#=/#=${EPREFIX}/#g" -i usr/share/applications/*.desktop || die
	fi

	readarray -t rpath_libs < <(find "${S}/opt/nvidia/${PN}/${PV}/host-linux-"* -name libparquet.so -o -name libarrow.so )
	for rpath_lib in "${rpath_libs[@]}"; do
		ebegin "fixing rpath for ${rpath_lib}"
		patchelf --set-rpath '$ORIGIN' "${rpath_lib}"
		eend $?
	done

	eapply_user
}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	rmdir usr/local/bin usr/local || die
	cp -a ./* "${ED}" || die
}
