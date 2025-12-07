# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CUDA_COMPAT=( 12 13 )

DESCRIPTION="A High-Performance CUDA Library for Sparse Matrix-Matrix Multiplication"
HOMEPAGE="https://docs.nvidia.com/cuda/cusparselt/ https://developer.nvidia.com/cusparselt-downloads"

SRC_URI="
	amd64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-x86_64/libcusparse_lt-linux-x86_64-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-x86_64/libcusparse_lt-linux-x86_64-${PV}_cuda13-archive.tar.xz
		)
	)
	arm64? (
		cuda_targets_12? (
			https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-sbsa/libcusparse_lt-linux-sbsa-${PV}_cuda12-archive.tar.xz
		)
		cuda_targets_13? (
			https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-sbsa/libcusparse_lt-linux-sbsa-${PV}_cuda13-archive.tar.xz
		)
	)
"

# The package contains a directory with the archive name minus the extension.
# So to handle arm64/amd64 we use WORKDIR here
S="${WORKDIR}"

LICENSE="NVIDIA-SDK-v2020.10.12 NVIDIA-cuSPARSELt-v2020.10.12"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~amd64-linux ~arm64-linux"
IUSE="+cuda_targets_12 cuda_targets_13"
RESTRICT="bindist mirror test"

REQUIRED_USE="
	|| ( ${CUDA_COMPAT[*]/#/cuda_targets_} )
"

QA_PREBUILT="/opt/cuda*/targets/*-linux/lib/*"


pkg_pretend() {
	echo "${WORKDIR}/lib${PN//lt/_lt}-linux-${narch}-${PV}_cuda${ver}-archive"
}

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

	for ver in "${CUDA_COMPAT[@]}"; do
		if use "cuda_targets_${ver}"; then
			CUDNN_PATH="/opt/cuda-${ver}"
			cd "${WORKDIR}/lib${PN//lt/_lt}-linux-${narch}-${PV}_cuda${ver}-archive" || die

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
