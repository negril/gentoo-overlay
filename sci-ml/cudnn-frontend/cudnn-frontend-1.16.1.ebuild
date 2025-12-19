# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cuda cmake edo

DESCRIPTION="A c++ wrapper for the cudnn backend API"
HOMEPAGE="https://github.com/NVIDIA/cudnn-frontend"

SRC_URI="https://github.com/NVIDIA/cudnn-frontend/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64"
IUSE="cuda_targets_11 cuda_targets_12 +cuda_targets_13 samples test"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	?? (
		cuda_targets_11
		cuda_targets_12
		cuda_targets_13
	)
"

RDEPEND="
	>=dev-libs/cudnn-9.0.0:=[cuda_targets_11(-)?,cuda_targets_12(+)?,cuda_targets_13(+)?]
"
DEPEND="${RDEPEND}
	dev-cpp/nlohmann_json
	test? (
		>dev-cpp/catch-3
		>=dev-libs/cudnn-9.15.0
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-1.11.0-fix.patch"
)

src_prepare() {
	cmake_src_prepare

	sed -e 's#"cudnn_frontend/thirdparty/nlohmann/json.hpp"#<nlohmann/json.hpp>#' \
		-i include/cudnn_frontend_utils.h || die

	rm -r include/cudnn_frontend/thirdparty || die
}

src_configure() {
	local narch
	if use amd64; then
		narch="x86_64"
	elif use arm64; then
		narch="sbsa"
	fi

	local mycmakeargs=(
		-DCUDNN_FRONTEND_BUILD_PYTHON_BINDINGS="no"
		-DCUDNN_FRONTEND_BUILD_SAMPLES="$(usex test "$(usex samples)")"
		-DCUDNN_FRONTEND_BUILD_TESTS="$(usex test)"
		-DCUDNN_FRONTEND_SKIP_JSON_LIB="no"
	)

	if use samples || use test; then
		if use cuda_targets_11; then
			CUDNN_PATH="${ESYSROOT}/opt/cuda-11"
			# mycmakeargs+=(
			# 	-DCUDNN_INCLUDE_DIR="${ESYSROOT}/opt/cuda-11/include"
			# 	-DCUDNN_LIBRARY_PATH="${ESYSROOT}/opt/cuda-11/$(get_libdir)"
			# )
		fi

		if use cuda_targets_12; then
			CUDNN_PATH="${ESYSROOT}/opt/cuda-12"
			# mycmakeargs+=(
			# 	-DCUDNN_INCLUDE_DIR="${ESYSROOT}/opt/cuda-12/include"
			# 	-DCUDNN_LIBRARY_PATH="${ESYSROOT}/opt/cuda-12/$(get_libdir)"
			# )
		fi
		export CUDNN_PATH
	fi

	# if use python; then
	# 	mycmakeargs+=(
	# 		-DCUDNN_FRONTEND_USE_SYSTEM_DLPACK="yes"
	# 	)
	# fi

	cmake_src_configure
}

src_test() {
	cuda_add_sandbox -w
	addwrite "/proc/self/task"

	edo "${BUILD_DIR}/bin/tests" '~[key]'

	if use samples; then
		edo "${BUILD_DIR}/bin/samples" -s
		edo "${BUILD_DIR}/bin/legacy_samples" -s
	fi

	cmake_src_test
}

src_install() {
	cmake_src_install

	if use test; then
		rm -R "${ED}/usr/bin/tests" || die
	fi
}
