# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="NVIDIA Accelerated Deep Learning on GPU library"
HOMEPAGE="https://developer.nvidia.com/cudnn"

SRC_URI="
	amd64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-${PV}_cuda13-archive.tar.xz
		)
	)
	arm64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-${PV}_cuda13-archive.tar.xz
		)
	)
"

S="${WORKDIR}"

LICENSE="NVIDIA-cuDNN"
SLOT="0/$(ver_cut 1-3)"
KEYWORDS="~amd64 ~arm64"
IUSE="cuda_targets_12 +cuda_targets_13"
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
	|| (
		cuda_targets_12
		cuda_targets_13
	)
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

	local vers=(
		12
		13
	)
	local CUDNN_PATH
	for ver in "${vers[@]}"; do
		if use "cuda_targets_${ver}"; then
			CUDNN_PATH="/opt/cuda-${ver}"
			cd "${WORKDIR}/cudnn-linux-${narch}-${PV}_cuda${ver}-archive" || die

			dodir "${CUDNN_PATH}/targets/${narch}-linux"
			mv \
				include lib \
				"${ED}${CUDNN_PATH}/targets/${narch}-linux" \
				|| die

			# Add include and lib symlinks
			dosym -r "${CUDNN_PATH}/targets/${narch}-linux/include" "${CUDNN_PATH}/include"
			dosym -r "${CUDNN_PATH}/targets/${narch}-linux/lib" "${CUDNN_PATH}/$(get_libdir)"

			find "${ED}/${CUDNN_PATH}" -empty -delete || die
		fi
	done
}
