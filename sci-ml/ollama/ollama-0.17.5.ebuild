# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# supports ROCM/HIP >=5.5, but we define 6.1 due to the eclass # TODO WHY?
ROCM_VERSION="6.1"

inherit cuda rocm
inherit cmake
inherit go-module systemd
inherit linux-info toolchain-funcs
inherit flag-o-matic

DESCRIPTION="Get up and running with Llama 3, Mistral, Gemma, and other language models"
HOMEPAGE="https://ollama.com"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ollama/ollama.git"
else
	MY_PV="${PV/_rc/-rc}"
	MY_P="${PN}-${MY_PV}"

	SRC_URI="
		https://github.com/ollama/${PN}/archive/refs/tags/v${MY_PV}.tar.gz
			-> ${MY_P}.gh.tar.gz
		https://github.com/gentoo-golang-dist/${PN}/releases/download/v${MY_PV}/${MY_P}-deps.tar.xz
	"

	if [[ "${PV}" != *_rc* ]]; then
	KEYWORDS="~amd64"
	fi
fi

LICENSE="MIT"
SLOT="0"

# IUSE ollama
IUSE="cpudetection cuda openmp rocm vulkan"
# IUSE ggml
# IUSE+=" opencl"
# wwma USE explained here: https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#hip
IUSE+=" wmma"
IUSE+=" +system-ggml"

# USE=examples requires (GGML_BUILD_EXAMPLES AND NOT GGML_BACKEND_DL)
GGML_REQUIRED_USE="
	wmma? (
		rocm
	)
"

REQUIRED_USE="
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

RESTRICT="mirror test"

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
	vulkan? (
		media-libs/vulkan-loader
	)
"
GGML_DEPEND="${GGML_COMMON_DEPEND}
	dev-cpp/nlohmann_json
	vulkan? (
		dev-util/vulkan-headers
	)
"
GGML_BDEPEND="
	${GGML_GPGPU_DEPEND}
	vulkan? (
		media-libs/shaderc
	)
"
unset GGML_COMMON_DEPEND GGML_GPGPU_DEPEND

COMMON_DEPEND="
"
RDEPEND="${COMMON_DEPEND}
	${GGML_RDEPEND}
	acct-group/${PN}
	>=acct-user/${PN}-3[cuda?]
"
DEPEND="${COMMON_DEPEND}
	${GGML_DEPEND}
	>=dev-lang/go-1.23.4
"
BDEPEND="
	${GGML_BDEPEND}
"
unset COMMON_DEPEND GGML_RDEPEND GGML_DEPEND GGML_BDEPEND

PATCHES=(
	"${FILESDIR}/${PN}-9999-use-GNUInstallDirs.patch"
	"${FILESDIR}/${PN}-9999-make-installing-runtime-deps-optional.patch"
)

pkg_pretend() {
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
	if [[ ${MERGE_TYPE} != binary ]] && use openmp; then
		tc-check-openmp
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

		go-module_live_vendor
	else
		go-module_src_unpack
	fi

	default

	# Already filter lto flags for ROCM
	# 963401
	if use rocm; then
		# copied from _rocm_strip_unsupported_flags
		strip-unsupported-flags
		export CXXFLAGS="$(test-flags-HIPCXX "${CXXFLAGS}")"
	fi
}

src_prepare() {
	cmake_src_prepare

	if use cuda; then
		cuda_src_prepare
	fi

	sed \
		-e "/set(GGML_CCACHE/s/ON/OFF/g" \
		-i CMakeLists.txt || die "Disable CCACHE sed failed"

	# TODO see src_unpack?
	# bug 963401
	sed \
		-e "s/ -O3//g" \
		-i \
			ml/backend/ggml/ggml/src/ggml-cpu/cpu.go \
		|| die "-O3 sed failed"

	# grep -Rl -e 'lib/ollama' -e '"..", "lib"'  --include '*.go'
	sed \
		-e "s/\"..\", \"lib\"/\"..\", \"$(get_libdir)\"/" \
		-e "s#\"lib/ollama\"#\"$(get_libdir)/ollama\"#" \
		-i \
			ml/backend/ggml/ggml/src/ggml.go \
			ml/path.go \
		|| die "libdir sed failed"

	if use rocm; then
		# --hip-version gets appended to the compile flags which isn't a known flag.
		# This causes rocm builds to fail because -Wunused-command-line-argument is turned on.
		# Use nuclear option to fix this.
		# Disable -Werror's from go modules.
		find "${S}" -name ".go" -exec sed -i "s/ -Werror / /g" {} + || die
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
		# -DGGML_CUDA="$(usex cuda)" # already used as source dir
		# -DGGML_CPU="yes"
		# -DGGML_HIP="$(usex rocm)" # already used as source dir
		# -DGGML_METAL="yes" # apple
		# missing from ml/backend/ggml/ggml/src/
		# -DGGML_CANN="yes"
		# -DGGML_MUSA="yes"
		# -DGGML_RPC="yes"
		# -DGGML_SYCL="yes"
		# -DGGML_OPENCL="$(usex opencl)"
		-DGGML_OPENMP="$(usex openmp)"
		# -DGGML_VULKAN="$(usex vulkan)" # already used as source dir

		"$(cmake_use_find_package vulkan Vulkan)"
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
	else
		mycmakeargs+=(
			-DCMAKE_CUDA_COMPILER="NOTFOUND"
		)
	fi

	if use rocm; then
		rocm_use_hipcc

		mycmakeargs+=(
			# ollama doesn't honor the default cmake options
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			# -DGPU_TARGETS="$(get_amdgpu_flags)"
			# -DCMAKE_HIP_ARCHITECTURES="$(get_amdgpu_flags)"

			# We don't want to the cuda backend
			-DCMAKE_HIP_PLATFORM="amd"
		)

		local -x HIP_PATH="${ESYSROOT}/usr"
	else
		mycmakeargs+=(
			-DCMAKE_HIP_COMPILER="NOTFOUND"
		)
	fi

	mycmakeargs+=(
		# -DCMAKE_INSTALL_BINDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/bin"
		# -DCMAKE_INSTALL_INCLUDEDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/include"
		# -DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/$(get_libdir)/${MY_PN}/$(get_libdir)"

		-DCMAKE_INSTALL_INCLUDEDIR="${EPREFIX}/usr/libexec/${MY_PN}/include"
		-DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/libexec/${MY_PN}/$(get_libdir)"
		-DCMAKE_INSTALL_RPATH="${EPREFIX}/usr/libexec/${MY_PN}/$(get_libdir)"

		-DOLLAMA_INSTALL_RUNTIME_DEPS="no"
	)

	cmake_src_configure
}

src_compile() {
	# export version information
	# https://github.com/gentoo/guru/pull/205
	# https://forums.gentoo.org/viewtopic-p-8831646.html
	local VERSION
	if [[ "${PV}" == *9999* ]]; then
		VERSION="$(
			git describe --tags --first-parent --abbrev=7 --long --dirty --always \
			| sed -e "s/^v//g"
		)"
	else
		VERSION="${PVR}"
	fi
	local EXTRA_GOFLAGS_LD=(
		# "-w" # disable DWARF generation
		# "-s" # disable symbol table
		"-X=github.com/ollama/ollama/version.Version=${VERSION}"
		"-X=github.com/ollama/ollama/server.mode=release"
			)
	GOFLAGS+=" '-ldflags=${EXTRA_GOFLAGS_LD[*]}'"

	ego build

	cmake_src_compile
}

src_install() {
	dobin ollama

	cmake_src_install

	newinitd "${FILESDIR}/ollama.init" "${PN}"
	newconfd "${FILESDIR}/ollama.confd" "${PN}"

	systemd_dounit "${FILESDIR}/ollama.service"
}

pkg_preinst() {
	keepdir /var/log/ollama
	fperms 750 /var/log/ollama
	fowners "${PN}:${PN}" /var/log/ollama
}

pkg_postinst() {
	if [[ -z ${REPLACING_VERSIONS} ]] ; then
		einfo "Quick guide:"
		einfo "\tollama serve"
		einfo "\tollama run llama3:70b"
		einfo
		einfo "See available models at https://ollama.com/library"
	fi

	if use cuda ; then
		einfo "When using cuda the user running ${PN} has to be in the video group or it won't detect devices."
		einfo "The ebuild ensures this for user ${PN} via acct-user/${PN}[cuda]"
	fi
}
