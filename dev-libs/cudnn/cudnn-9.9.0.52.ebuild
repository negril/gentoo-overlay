# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="NVIDIA Accelerated Deep Learning on GPU library"
HOMEPAGE="https://developer.nvidia.com/cudnn"

SRC_URI="
	amd64? (
		cuda_targets_11? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-${PV}_cuda11-archive.tar.xz
		)
		cuda_targets_12? (
		https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-${PV}_cuda12-archive.tar.xz
	)
	)
	arm64? (
		cuda_targets_11? (
			https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-${PV}_cuda11-archive.tar.xz
		)
		cuda_targets_12? (
		https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-${PV}_cuda12-archive.tar.xz
	)
	)
"

S="${WORKDIR}"

LICENSE="NVIDIA-cuDNN"
SLOT="0/$(ver_cut 1-3)"
KEYWORDS="~amd64 ~arm64 ~amd64-linux ~arm64-linux"
IUSE="cuda_targets_11 +cuda_targets_12"
RESTRICT="bindist test"

RDEPEND="
	cuda_targets_11? (
		=dev-util/nvidia-cuda-toolkit-11*
	)
	cuda_targets_12? (
		=dev-util/nvidia-cuda-toolkit-12*
	)
"

REQUIRED_USE="
	^^ (
		cuda_targets_11
		cuda_targets_12
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

	local CUDNN_PATH
	if use cuda_targets_11; then
		CUDNN_PATH="/opt/cuda-11"
		cd "${WORKDIR}/cudnn-linux-${narch}-${PV}_cuda11-archive" || die

		dodir "${CUDNN_PATH}/targets/${narch}-linux"
		mv \
			include lib \
			"${ED}${CUDNN_PATH}/targets/${narch}-linux" \
			|| die

		# Add include and lib symlinks
		dosym -r "${CUDNN_PATH}/targets/${narch}-linux/include" "${CUDNN_PATH}/include"
		dosym -r "${CUDNN_PATH}/targets/${narch}-linux/lib" "${CUDNN_PATH}/lib64"

		find "${ED}/${CUDNN_PATH}" -empty -delete || die
	fi

	if use cuda_targets_12; then
		CUDNN_PATH="/opt/cuda-12"
	cd "${WORKDIR}/cudnn-linux-${narch}-${PV}_cuda12-archive" || die

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
}
