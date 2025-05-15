# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake cuda
MY_PV=$(ver_cut 1-2)
PV_BUILD="-35015278"

DESCRIPTION="NVIDIA Ray Tracing Engine"
HOMEPAGE="https://developer.nvidia.com/optix"
SRC_URI="
	!headers-only? (
		amd64? (
			https://developer.download.nvidia.com/designworks/optix/secure/${PV}/NVIDIA-OptiX-SDK-${PV}-linux64-x86_64${PV_BUILD}.sh
		)
		arm64? (
			https://developer.download.nvidia.com/designworks/optix/secure/${PV}/NVIDIA-OptiX-SDK-${PV}-linux64-aarch64${PV_BUILD}.sh
		)
	)
	headers-only? (
		https://github.com/NVIDIA/optix-dev/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	)
"
S="${WORKDIR}"

LICENSE="NVIDIA-SDK"
SLOT="0/$(ver_cut 1)"
KEYWORDS="~amd64 ~arm64"
IUSE="+headers-only"
RESTRICT="bindist mirror !headers-only? ( fetch )"

RDEPEND=">=x11-drivers/nvidia-drivers-555"

pkg_nofetch() {
	einfo "Please download ${A} from:"
	einfo "  ${HOMEPAGE}"
	einfo "and move it to your distfiles directory."
}

src_unpack() {
	if use headers-only; then
		default
	else
		skip="$(grep -a ^tail "${DISTDIR}/${A}" | tail -n1 | cut -d' ' -f 3)"
		tail -n "${skip}" "${DISTDIR}/${A}" | tar -zx
		assert "unpacking ${A} failed"
	fi
}

src_prepare() {
	if use headers-only; then
		default
	else
		export CMAKE_USE_DIR="${WORKDIR}/SDK"
		# cmake_run_in "${S}_build" \
		cmake_src_prepare
	fi
}

src_configure() {
	use headers-only && return

	filter-lto

	# local -x CUDAHOSTCXX="$(cuda_gccdir)"
	local -x CUDAHOSTLD="$(tc-getCXX)"
	local mycmakeargs=(
		-DCUDA_HOST_COMPILER="$(cuda_gccdir)"
	)

	# cmake_run_in "${S}_build" \
	cmake_src_configure
}

src_compile() {
	use headers-only && return

	# cmake_run_in "${S}_build" \
	cmake_src_compile
}

src_test() {
	use headers-only && return

	# cmake_run_in "${S}_build" \
	cmake_src_test
}

src_install() {
	insinto "/opt/${PN}"

	if use headers-only; then
		cd "${PN}-dev-${PV}" || die
		doins -r include/

		dodoc README.md
		return
	fi

	# cd "${WORKDIR}/SDK_build" && cmake -P cmake_install.cmake
	cmake_run_in "${BUILD_DIR}" cmake -P cmake_install.cmake

	DOCS=( doc/OptiX_{API_Reference,Programming_Guide}_${PV}.pdf )
	einstalldocs
}
