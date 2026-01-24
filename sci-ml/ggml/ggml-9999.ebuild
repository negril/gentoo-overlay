# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{13..14} )
ROCM_VERSION="6.3"
inherit cuda rocm linux-info
inherit cmake python-any-r1 toolchain-funcs

DESCRIPTION="Tensor library for machine learning"
HOMEPAGE="https://github.com/ggml-org/ggml"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ggml-org/ggml.git"
else
	# No releases but are planned
	# https://github.com/ggml-org/ggml/issues/1086
	COMMIT="b96890f3ab5ffbdbe56bc126df5366c34bd08d39"

	SRC_URI="
		https://github.com/ggml-org/ggml/archive/${COMMIT}.tar.gz
			-> ${PN}-${COMMIT}.tar.gz
	"
	S="${WORKDIR}/${PN}-${COMMIT}"

	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0/${PV}"

IUSE="blas openblas blis mkl"
IUSE+=" examples cuda opencl openmp hip test vulkan"

declare -A CPU_FEATURES=(
	[AMX_BF16]="x86"
	[AMX_INT8]="x86"
	[AMX_TILE]="x86"
	[AVX2]="x86"
	[AVX512_BF16]="x86"
	[AVX512_VBMI]="x86;avx512vbmi"
	[AVX512_VNNI]="x86"
	[AVX]="x86"
	[AVX_VNNI]="x86"
	[BMI2]="x86"
	[F16C]="x86"
	[FMA]="x86;fma3"
	[SSE42]="x86;sse4_2"
	[VSX]="ppc"
)
add_cpu_features_use() {
	for flag in "${!CPU_FEATURES[@]}"; do
		IFS=$';' read -r arch use <<< "${CPU_FEATURES[${flag}]}"
		IUSE+=" cpu_flags_${arch}_${use:-${flag,,}}"
	done
}
add_cpu_features_use

RESTRICT="!test? ( test )"

COMMON_DEPEND="
	blas? (
		virtual/blas
		openblas? (
			sci-libs/openblas:=
		)
		!openblas? (
			blis? (
				sci-libs/blis:=
			)
			!blis? (
				mkl? (
					sci-libs/mkl
				)
			)
		)
	)
"
GPGPU_DEPEND="
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
		x11-drivers/nvidia-drivers
	)
	hip? (
		>=dev-util/hip-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=[${ROCM_USEDEP}]
	)
"
RDEPEND="${COMMON_DEPEND}
	${GPGPU_DEPEND}
	opencl? ( virtual/opencl )
	vulkan? ( media-libs/vulkan-loader )
"
DEPEND="${COMMON_DEPEND}
	dev-cpp/nlohmann_json
	opencl? ( dev-util/opencl-headers )
	vulkan? ( dev-util/vulkan-headers )
"
BDEPEND="
	${GPGPU_DEPEND}
	virtual/pkgconfig
	opencl? ( ${PYTHON_DEPS} )
	vulkan? ( dev-util/glslang )
"

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
	use opencl && python-any-r1_pkg_setup

	if use hip; then
		linux-info_pkg_setup
		if linux-info_get_any_version && linux_config_exists; then
			if ! linux_chkconfig_present HSA_AMD_SVM; then
				ewarn "To use ROCm/HIP, you need to have HSA_AMD_SVM option enabled in your kernel."
			fi
		fi
	fi
}

src_prepare() {
	cmake_src_prepare

	if use cuda; then
		cuda_src_prepare
	fi
}

src_configure() {
	local mycmakeargs=(
		-DGGML_BACKEND_DL="no"
		-DGGML_CPU_ALL_VARIANTS="no"

		-DGGML_NATIVE="no"
		# -DGGML_LTO="no"
		-DGGML_CCACHE="no"

		-DGGML_BUILD_TESTS="$(usex test)"
		-DGGML_BUILD_EXAMPLES="$(usex examples)" # todo

		-DGGML_BLAS="$(usex blas)"
		-DGGML_CUDA="$(usex cuda)"
		-DGGML_HIP="$(usex hip)"
		-DGGML_OPENCL="$(usex opencl)"
		-DGGML_OPENMP="$(usex openmp)"
		-DGGML_VULKAN="$(usex vulkan)"
		-DGGML_VULKAN_TESTS="$(usex vulkan "$(usex test)")"

		# features
		-DGGML_AVX512="no" # no-op on its own
		-DGGML_LASX="no" # only appends -mlasx
		-DGGML_LSX="no" # only appends -mlsx
		-DGGML_RVV="no" # no-op on its own
		-DGGML_RV_ZFH="no" # adds march
		-DGGML_XTHEADVECTOR="no" # adds march
		-DGGML_VXE="no" # s390x, no use flag
		-DGGML_NNPA="no" # s390x, no use flag
	)

	if [[ ${PV} != 9999 ]]; then
		mycmakeargs+=(
			-DGGML_BUILD_NUMBER="${PVR}" # avoid git
			-DGGML_BUILD_COMMIT="${COMMIT}"
		)
	fi

	for flag in "${!CPU_FEATURES[@]}"; do
		IFS=$';' read -r arch use <<< "${CPU_FEATURES[${flag}]}"
		mycmakeargs+=(
			-D"GGML_${flag}=$(usex "cpu_flags_${arch}_${use:-${flag,,}}")"
		)
	done

	if tc-is-lto ; then
		mycmakeargs+=(
			-DGGML_LTO="yes"
		)
	fi

	if use blas; then
# 		mycmakeargs+=(
# 			-DGGML_BLAS="yes"
# 			-DGENTOO_REMOVE_CMAKE_BLAS_HACK=ON
# 		)
		if use openblas ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="OpenBLAS"
			)
		elif use blis ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="FLAME"
			)
		elif use mkl ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Intel"
			)
		else
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Generic"
			)
		fi
	fi

	if use cuda ; then
		local -x CUDAHOSTCXX="$(cuda_gccdir)"
		# tries to recreate dev symlinks
		cuda_add_sandbox
		addpredict "/dev/char/"
		mycmakeargs+=(
			-DCMAKE_CUDA_ARCHITECTURES=89
		)
	fi

	if use opencl ; then
		mycmakeargs+=(
			-DGGML_OPENCL_USE_ADRENO_KERNELS="no"
		)
	fi

	if use hip; then
		rocm_use_hipcc
		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		)
	fi

	cmake_src_configure
}

src_test() {
	if use cuda; then
		cuda_add_sandbox -w
	fi

	[[ -c /dev/udmabuf ]] && addwrite /dev/udmabuf

# 	ln -rs "${CMAKE_USE_DIR}/models" "${BUILD_DIR}" || die

# 	if use test; then
# 		mkdir -p "${HOME}/.cache/llama.cpp" || die
# 		cp "${DISTDIR}/ggml-org_models_tinyllamas_stories15M-q4_0.gguf" "${HOME}/.cache/llama.cpp/" || die
# 		cp "${DISTDIR}/stories260K.gguf" "${BUILD_DIR}/examples/eval-callback/" || die
# 		mkdir -p "${BUILD_DIR}/models/7B" || die
# 		cp "${DISTDIR}/ggml-model-f16.gguf" "${BUILD_DIR}/models/7B/" || die
# 	fi

# 	addwrite "/proc/self/mem"
# 	addwrite "/proc/PID/mem"

	# insert into cmake EXTRA_ARGS --offline

# 	local CMAKE_SKIP_TESTS=(
# 		 # needs network
# 		"^test-arg-parser$"
# 	)
#
# 	if use cuda && { use opencl || use vulkan; } then
# 		CMAKE_SKIP_TESTS+=(
# 			"^test-thread-safety$"
# 			"^test-backend-ops$"
# 		)
# 	fi

	if use cuda && { use opencl || use vulkan; } then
		CMAKE_SKIP_TESTS+=(
			"^test-backend-ops$"
		)
	fi

	cmake_src_test -j1
}
