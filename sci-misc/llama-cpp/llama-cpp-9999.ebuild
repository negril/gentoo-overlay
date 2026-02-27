# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# TODO USE=examples has no install rule

EAPI=8

# supports ROCM/HIP >=5.5, but we define 6.1 due to the eclass # TODO WHY?
ROCM_VERSION="6.1"

PYTHON_COMPAT=( python3_{12..14} )

DISTUTILS_USE_PEP517="poetry"
DISTUTILS_SINGLE_IMPL=1
DISTUTILS_OPTIONAL=1

TINY_LLAMAS_COMMIT="99dd1a73db5a37100bd4ae633f4cfce6560e1567"
MODELS_MOVED_COMMIT="10b4268bd9cc0f56bbb8d58f0aa699d161eb3d26"

inherit cuda rocm
inherit cmake
inherit distutils-r1
# inherit python-any-r1
inherit linux-info toolchain-funcs

DESCRIPTION="Port of Facebook's LLaMA model in C/C++"
HOMEPAGE="https://github.com/ggml-org/llama.cpp"

MY_PN="${PN/-/.}"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ggml-org/${MY_PN}.git"
else
	MY_PV="b${PV#0_pre}"
	MY_P="${MY_PN}-${MY_PV}"

	SRC_URI="
		https://github.com/ggml-org/${MY_PN}/archive/refs/tags/${MY_PV}.tar.gz
			-> ${MY_P}.tar.gz
	"
	S="${WORKDIR}/${MY_P}"

	KEYWORDS="~amd64"
fi

STORIES15M="
	https://huggingface.co/ggml-org/tiny-llamas/resolve/${TINY_LLAMAS_COMMIT}/stories15M-q4_0.gguf
		-> ggml-org_models_tinyllamas_stories15M-q4_0-${TINY_LLAMAS_COMMIT}.gguf
"

GGML_SRC_URI="
	test? (
		${STORIES15M}
		https://huggingface.co/ggml-org/tiny-llamas/resolve/${TINY_LLAMAS_COMMIT}/stories260K.gguf
			-> ggml-org_models_tinyllamas_stories260K-${TINY_LLAMAS_COMMIT}.gguf
		https://huggingface.co/ggml-org/models-moved/resolve/${MODELS_MOVED_COMMIT}/tinyllama-1.1b/ggml-model-f16.gguf
			-> ggml-org_models_models-ggml-model-f16-${MODELS_MOVED_COMMIT}.gguf
	)
"

SRC_URI+="
	examples? (
		${STORIES15M}
	)
	!system-ggml? (
		${GGML_SRC_URI}
	)
"
unset GGML_SRC_URI

LICENSE="MIT"
SLOT="0/${PV#0_pre}"

# IUSE ollama
IUSE="cpudetection cuda openmp rocm vulkan"
# IUSE ggml
IUSE+=" opencl"
# wwma USE explained here: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#hip
IUSE+=" wmma"
IUSE+=" system-ggml"
IUSE+=" test"
IUSE+=" examples"
# IUSE llama-cpp
IUSE+=" python ssl +tools"

# USE=examples requires (GGML_BUILD_EXAMPLES AND NOT GGML_BACKEND_DL)
GGML_REQUIRED_USE="
	examples? (
		!cpudetection
	)
	wmma? (
		rocm
	)
"

REQUIRED_USE="
	python? (
		${PYTHON_REQUIRED_USE}
	)
	test? (
		tools
	)
	system-ggml? (
		${GGML_REQUIRED_USE}
	)
"

# blas-utils.eclass {{{
BLAS_BACKENDS="blis mkl openblas"
BLAS_REQUIRED_USE="blas? ( ?? ( ${BLAS_BACKENDS} ) )"

IUSE+=" blas flexiblas ${BLAS_BACKENDS}"
REQUIRED_USE+=" ${BLAS_REQUIRED_USE}"
# }}}

# cpu-features.eclass {{{
declare -rgA CPU_FEATURES=(
	[SSE42]="x86;sse4_2"
	[AVX]="x86"
	[AVX2]="x86"
	[BMI2]="x86"
	[AVX_VNNI]="x86"
	[FMA]="x86;fma3"
	[F16C]="x86"
	[AMX_TILE]="x86"
	[AMX_INT8]="x86"
	[AMX_BF16]="x86"
	[AVX512]="x86;avx512f" # no-op on its own
	[AVX512_VBMI]="x86;avx512vbmi"
	[AVX512_VNNI]="x86"
	[AVX512_BF16]="x86"

	# [VSX]="ppc"

	# [RVV]="riscv" # no-op on its own
	# [RV_ZFH]="riscv" # adds march
	# [XTHEADVECTOR]="riscv" # adds march

	# [LASX]="loong" # only appends -mlasx
	# [LSX]="loong" # only appends -mlsx

	# s390x (z14 or later required)
	# [VXE]="s390" # no use flag
	# [NNPA]="s390" # no use flag
)
add_cpu_features_use() {
	for flag in "${!CPU_FEATURES[@]}"; do
		IFS=$';' read -r arch use <<< "${CPU_FEATURES[${flag}]}"
		IUSE+=" cpu_flags_${arch}_${use:-${flag,,}}"
	done
}
add_cpu_features_use
# }}}

RESTRICT="mirror !test? ( test )"

# RDEPEND="${PYTHON_DEPS}"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

# BDEPEND="python? ( ${BDEPEND} )"
# RDEPEND="python? ( ${RDEPEND} )"

# FindBLAS.cmake
# If Fortran is an enabled compiler it sets BLAS_mkl_THREADING to gnu. -> sci-libs/mkl[gnu-openmp]
# If Fortran is not an enabled compiler it sets BLAS_mkl_THREADING to intel. -> sci-libs/mkl[llvm-openmp]
GGML_COMMON_DEPEND="
	blas? (
		flexiblas? (
			sci-libs/flexiblas[blis?,mkl?,openblas?,openmp?]
		)
		!flexiblas? (
			blis? (
				sci-libs/blis:=[openmp?]
			)
			mkl? (
				sci-libs/mkl[llvm-openmp]
			)
			openblas? (
				sci-libs/openblas[openmp?]
			)
		)
		virtual/blas[flexiblas=]
	)
"
GGML_GPGPU_DEPEND="
	cuda? (
		dev-util/nvidia-cuda-toolkit:=
		x11-drivers/nvidia-drivers
	)
	rocm? (
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=
		wmma? (
			>=sci-libs/rocWMMA-${ROCM_VERSION}:=
		)
	)
"
GGML_RDEPEND="${GGML_COMMON_DEPEND}
	${GGML_GPGPU_DEPEND}
	opencl? (
		virtual/opencl
	)
	vulkan? (
		media-libs/vulkan-loader
	)
"
GGML_DEPEND="${GGML_COMMON_DEPEND}
	dev-cpp/nlohmann_json
	opencl? (
		dev-util/opencl-headers
	)
	vulkan? (
		dev-util/vulkan-headers
	)
"
GGML_BDEPEND="
	${GGML_GPGPU_DEPEND}
	opencl? (
		${PYTHON_DEPS}
	)
	vulkan? (
		media-libs/shaderc
	)
"
unset GGML_COMMON_DEPEND GGML_GPGPU_DEPEND

COMMON_DEPEND="
	system-ggml? (
		sci-ml/ggml:=
	)
	tools? (
		ssl? (
			dev-libs/openssl:=
		)
	)
"
# numpy is used by convert_hf_to_gguf.py # TODO python?
# 	RDEPEND="${PYTHON_DEPS}"
RDEPEND="${COMMON_DEPEND}
	!system-ggml? (
		${GGML_RDEPEND}
	)
	dev-python/numpy
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/numpy[${PYTHON_USEDEP}]
			sci-ml/sentencepiece[${PYTHON_USEDEP}]
			=dev-python/protobuf-5*[${PYTHON_USEDEP}]
		')
		>=sci-ml/pytorch-2.2.0[${PYTHON_SINGLE_USEDEP}]
		=sci-ml/transformers-4*[${PYTHON_SINGLE_USEDEP}]
	)
"
DEPEND="${COMMON_DEPEND}
	dev-cpp/nlohmann_json
	!system-ggml? (
		${GGML_DEPEND}
	)
"
# 	BDEPEND="${DISTUTILS_DEPS}"
# we set EGIT_LFS by hand
# 	python? ( ${BDEPEND} )
# 	dev-util/patchelf
BDEPEND="
	!system-ggml? (
		${GGML_BDEPEND}
	)
"
unset COMMON_DEPEND GGML_RDEPEND GGML_DEPEND GGML_BDEPEND

pkg_pretend() {
	if use system-ggml; then
		return
	fi

	if [[ ${MERGE_TYPE} != binary ]] && use openmp; then
		tc-check-openmp
	fi

	if use cpudetection; then
		if use amd64; then
			if use cpu_flags_x86_f16c && use cpu_flags_x86_avx2 && use cpu_flags_x86_fma3 && ! use cpu_flags_x86_bmi2; then
				ewarn
				ewarn "CPU_FLAGS_X86: bmi2 not enabled."
				ewarn "  Not building haswell runner."
				ewarn "  Not building skylakex runner."
				ewarn "  Not building icelake runner."
				ewarn "  Not building alderlake runner."
				ewarn
				if grep bmi2 /proc/cpuinfo > /dev/null; then
					ewarn "bmi2 found in /proc/cpuinfo"
					ewarn
				fi
			fi
		fi
	fi
}

pkg_setup() {
	if use system-ggml; then
		return
	fi

	if [[ ${MERGE_TYPE} != binary ]] && use openmp; then
		tc-check-openmp
	fi

	if use opencl; then
		python-single-r1_pkg_setup
	fi

	if use rocm; then
		linux-info_pkg_setup
		if linux-info_get_any_version && linux_config_exists; then
			if ! linux_chkconfig_present HSA_AMD_SVM; then
				ewarn "To use ROCm/HIP, you need to have HSA_AMD_SVM option enabled in your kernel."
			fi
		fi
	fi
}

src_unpack() {
	if [[ "${PV}" == *9999* ]]; then
		git-r3_src_unpack

		if use test; then
			EGIT_REPO_URI="https://huggingface.co/ggml-org/vocabs" \
			EGIT_CHECKOUT_DIR="${S}/models/ggml-vocabs" \
			EGIT_LFS="yes" \
				git-r3_src_unpack
		fi
	fi

	default
}

src_prepare() {
	cmake_src_prepare

	if use examples; then
		mkdir -p "${BUILD_DIR}/tinyllamas" || die
		cp "${DISTDIR}/ggml-org_models_tinyllamas_stories15M-q4_0-${TINY_LLAMAS_COMMIT}.gguf" \
			"${BUILD_DIR}/tinyllamas/stories15M-q4_0.gguf" || die
	fi

	if use python; then
		distutils-r1_python_prepare_all
	fi

	if use system-ggml; then
		return
	fi

	if use cuda; then
		cuda_src_prepare
	fi
}

src_configure() {
	local mycmakeargs=()

	mycmakeargs+=(
		# backends end up in /usr/bin otherwise
		-DGGML_BACKEND_DL="$(usex cpudetection)"

		-DGGML_CPU_ALL_VARIANTS="$(usex cpudetection)"

		-DGGML_CCACHE="no"
		-DGGML_NATIVE="no" # don't set march

		#
		#

		-DGGML_BLAS="$(usex blas)"
		-DGGML_CUDA="$(usex cuda)"
		-DGGML_CPU="yes"
		-DGGML_HIP="$(usex rocm)"
		# -DGGML_METAL="yes" # apple

		# -DGGML_CANN="yes"
		# -DGGML_MUSA="yes"
		-DGGML_RPC="yes"
		# -DGGML_SYCL="yes"
		-DGGML_OPENCL="$(usex opencl)"
		-DGGML_OPENMP="$(usex openmp)"
		-DGGML_VULKAN="$(usex vulkan)"
		-DGGML_VULKAN_TESTS="$(usex vulkan "$(usex test)")"
	)

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
		if use flexiblas ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="FlexiBLAS"
			)
		elif use blis ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="FLAME"
			)
		elif use mkl ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Intel10_64lp"
			)
		# elif use nvhpc ; then
		# 	mycmakeargs+=(
		# 		-DGGML_BLAS_VENDOR="NVHPC"
		# 	)
		elif use openblas ; then
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="OpenBLAS"
			)
		else
			mycmakeargs+=(
				-DGGML_BLAS_VENDOR="Generic"
			)
		fi
	fi

	if use cpudetection; then
		mycmakeargs+=(
			# TODO causes duplicate install warning but breaks detection otherwise ollama/issues/13614
			-DGGML_BACKEND_DIR="${EPREFIX}/usr/$(get_libdir)/${PN}"

			-DCMAKE_BUILD_RPATH="\$ORIGIN"
			# -DCMAKE_INSTALL_RPATH="${EPREFIX}/usr/$(get_libdir)/${PN}"
			-DCMAKE_INSTALL_RPATH="\$ORIGIN"
		)
	fi

	if use cuda; then
		local -x CUDAHOSTCXX CUDAHOSTLD
		CUDAHOSTCXX="$(cuda_gccdir)"
		CUDAHOSTLD="$(tc-getCXX)"

		# default to all-major for now until cuda.eclass is updated
		if [[ ! -v CUDAARCHS ]]; then
			local CUDAARCHS="all-major"
		fi

		mycmakeargs+=(
			-DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
		)

		cuda_add_sandbox -w
		addpredict "/dev/char/"
	fi

	if use opencl ; then
		mycmakeargs+=(
			-DGGML_OPENCL_USE_ADRENO_KERNELS="no"
		)
	fi

	if use rocm; then
		rocm_use_hipcc

		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			# -DGPU_TARGETS="$(get_amdgpu_flags)"
			# -DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"

			# We don't want to the cuda backend
			-DCMAKE_HIP_PLATFORM="amd"
		)

		local -x HIP_PATH="${ESYSROOT}/usr"
	fi

	if use system-ggml; then
		mycmakeargs=(
		)
	fi

	if [[ "${PV}" != *9999* ]]; then
		mycmakeargs+=(
			 # avoid git
			-DBUILD_NUMBER="${PR}"
			-DBUILD_COMMIT="${COMMIT}"
			-DCMAKE_DISABLE_FIND_PACKAGE_Git=ON
		)
	fi

	mycmakeargs+=(
		# -DCMAKE_INSTALL_BINDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/bin"
		# -DCMAKE_INSTALL_INCLUDEDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/include"
		# -DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/$(get_libdir)"

		-DCMAKE_INSTALL_INCLUDEDIR="${EPREFIX}/usr/libexec/${MY_PN}/include"
		-DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/libexec/${MY_PN}/$(get_libdir)"
		-DCMAKE_INSTALL_RPATH="${EPREFIX}/usr/libexec/${MY_PN}/$(get_libdir)"

		-DLLAMA_USE_SYSTEM_GGML="$(usex system-ggml)"

		-DLLAMA_BUILD_COMMON="yes"
		-DLLAMA_BUILD_EXAMPLES="$(usex examples)"
		-DLLAMA_BUILD_SERVER="yes"
		-DLLAMA_BUILD_TESTS="$(usex test)"
		-DLLAMA_BUILD_TOOLS="$(usex tools)"

		-DLLAMA_TESTS_INSTALL="no"

		-DLLAMA_OPENSSL="$(usex ssl)"
	)

	cmake_src_configure

	if use python ; then
		distutils-r1_src_configure
	fi
}

src_compile() {
	cmake_src_compile

	if use python ; then
		distutils-r1_src_compile
	fi
}

ggml_src_test() {
	if use cuda; then
		cuda_add_sandbox -w
	fi

	[[ -c /dev/udmabuf ]] && addwrite /dev/udmabuf

	ln -rs "${CMAKE_USE_DIR}/models" "${BUILD_DIR}" || die

	mkdir -p "${BUILD_DIR}/examples/eval-callback" || die
	cp \
		"${DISTDIR}/ggml-org_models_tinyllamas_stories260K-${TINY_LLAMAS_COMMIT}.gguf" \
		"${BUILD_DIR}/examples/eval-callback/" \
		|| die

	mkdir -p "${BUILD_DIR}/models/7B" || die
	cp \
		"${DISTDIR}/ggml-org_models_models-ggml-model-f16-${MODELS_MOVED_COMMIT}.gguf" \
		"${BUILD_DIR}/models/7B/" \
		|| die
}

src_test() {
	if ! use system-ggml; then
		ggml_src_test
	fi

	mkdir -p "${HOME}/.cache/${MY_PN}" || die
	cp \
		"${DISTDIR}/ggml-org_models_tinyllamas_stories15M-q4_0-${TINY_LLAMAS_COMMIT}.gguf" \
		"${HOME}/.cache/${MY_PN}/" \
		|| die

	# insert into cmake EXTRA_ARGS --offline
	CMAKE_SKIP_TESTS+=(
		"test-chat"

		# needs network
		"^test-arg-parser$"

		"^test-backend-ops$"
	)

# 	if ! use system-ggml; then
# 		if use cuda && { use opencl || use vulkan; } then
# 			CMAKE_SKIP_TESTS+=(
# 				"^test-thread-safety$"
# 				"^test-backend-ops$"
# 			)
# 		fi
# 	fi

	local -x TEST_VERBOSE=1
	local -x CTEST_JOBS=1
	cmake_src_test

	if use python ; then
		distutils-r1_src_test
	fi
}

src_install() {
	cmake_src_install

	# if use examples; then
	# 	if use test; then
	# 		rm -v "${BUILD_DIR}/bin/"test-* || die
	# 	fi

	# 	exeinto "/usr/libexec/${PN}"
	# 	doexe "${BUILD_DIR}/bin/"*
	# fi

	if ! use system-ggml; then
		# dobin "${BUILD_DIR}/bin/rpc-server"
		# patchelf --remove-rpath "${ED}/usr/bin/rpc-server" || die

		# avoid clashing with whisper.cpp
		# rm -rf "${ED}/usr/include"
		:
	fi

	if use python ; then
		distutils-r1_src_install
	fi
}
