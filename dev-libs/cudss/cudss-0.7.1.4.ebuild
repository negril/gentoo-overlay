# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CUDA_COMPAT=( 12 13 )

DESCRIPTION="NVIDIA Accelerated Deep Learning on GPU library"
HOMEPAGE="https://developer.nvidia.com/cudnn"

SRC_URI="
	amd64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cudss/redist/libcudss/linux-x86_64/libcudss-linux-x86_64-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cudss/redist/libcudss/linux-x86_64/libcudss-linux-x86_64-${PV}_cuda13-archive.tar.xz
		)
	)
	arm64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cudss/redist/libcudss/linux-sbsa/libcudss-linux-sbsa-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cudss/redist/libcudss/linux-sbsa/libcudss-linux-sbsa-${PV}_cuda13-archive.tar.xz
		)
	)
"

# The package contains a directory with the archive name minus the extension.
# So to handle arm64/amd64 we use WORKDIR here
S="${WORKDIR}"

LICENSE="NVIDIA-cuDSS"
SLOT="0/$(ver_cut 1-3)"
KEYWORDS="~amd64 ~arm64"
IUSE="+cuda_targets_12 cuda_targets_13"
RESTRICT="bindist test"

RDEPEND="
	cuda_targets_12? (
		=dev-util/nvidia-cuda-toolkit-12*
	)
	cuda_targets_13? (
		=dev-util/nvidia-cuda-toolkit-13*
	)
"

REQUIRED_USE="
	|| ( ${CUDA_COMPAT[*]/#/cuda_targets_} )
"

QA_PREBUILT="/opt/cuda*/targets/*-linux/lib/*"

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	local narch
	if use amd64; then
		narch="x86_64"
	elif use arm64; then
		narch="sbsa"
	fi

	local CUDSS_PATH

	for ver in "${CUDA_COMPAT[@]}"; do
		if use "cuda_targets_${ver}"; then
			CUDSS_PATH="/opt/cuda-${ver}"
			cd "${WORKDIR}/lib${PN}-linux-${narch}-${PV}_cuda${ver}-archive" || die

			dodir "${CUDSS_PATH}/targets/${narch}-linux"
			mv \
				include lib \
				"${ED}${CUDSS_PATH}/targets/${narch}-linux" \
				|| die

			# Add include and lib symlinks
			dosym -r "${CUDSS_PATH}/targets/${narch}-linux/include" "${CUDSS_PATH}/include"
			dosym -r "${CUDSS_PATH}/targets/${narch}-linux/lib" "${CUDSS_PATH}/$(get_libdir)"

			find "${ED}/${CUDSS_PATH}" -empty -delete || die
		fi
	done
}
