# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# keep in sync with blender
PYTHON_COMPAT=( python3_{12..14} )

# Check this on updates
LLVM_COMPAT=( {18..23} )

inherit cmake cuda flag-o-matic llvm-r2 toolchain-funcs python-single-r1

DESCRIPTION="Advanced shading language for production GI renderers"
HOMEPAGE="https://www.imageworks.com/technology/opensource https://github.com/AcademySoftwareFoundation/OpenShadingLanguage"

if [[ ${PV} == *9999* ]] ; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/AcademySoftwareFoundation/OpenShadingLanguage.git"
	if [[ ${PV} != 9999* ]] ; then
		EGIT_BRANCH="dev-$(ver_cut 1-2)"
	fi
else
	# If a development release, please don't keyword!
	SRC_URI="https://github.com/AcademySoftwareFoundation/OpenShadingLanguage/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/OpenShadingLanguage-${PV}"

	KEYWORDS="~amd64 ~arm ~arm64 ~ppc64"
fi

LICENSE="BSD"
SLOT="0/$(ver_cut 1-2)" # based on SONAME

X86_CPU_FEATURES=(
	sse2:sse2
	sse3:sse3
	ssse3:ssse3
	sse4_1:sse4.1
	sse4_2:sse4.2
	avx:avx
	avx2:avx2
	avx512f:avx512f
	f16c:f16c
)
CPU_FEATURES=( "${X86_CPU_FEATURES[@]/#/cpu_flags_x86_}" )

IUSE="+clang-cuda debug doc gui libcxx nofma optix partio test ${CPU_FEATURES[*]%:*} python"

RESTRICT="!test? ( test )"

REQUIRED_USE="${PYTHON_REQUIRED_USE}
	optix? ( clang-cuda )
"

RDEPEND="
	dev-libs/pugixml
	>=media-libs/openimageio-2.4:=
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/pybind11[${PYTHON_USEDEP}]
			media-libs/openimageio[python,${PYTHON_SINGLE_USEDEP}]
		')
	)
	partio? ( media-libs/partio )
	gui? (
		dev-qt/qtbase:6[gui,widgets,opengl]
	)
"

DEPEND="${RDEPEND}
	dev-util/patchelf
	>=media-libs/openexr-3
	virtual/zlib:=
	test? (
		media-fonts/droid
		optix? (
			clang-cuda? (
				dev-util/nvidia-cuda-toolkit
			)
			dev-libs/optix
		)
	)
"
BDEPEND="
	sys-devel/bison
	sys-devel/flex
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${PN}-include-cstdint.patch"
)

cuda_get_host_compiler() {
	if [[ -v NVCC_CCBIN ]]; then
		echo "${NVCC_CCBIN}"
		return
	fi

	if [[ -v CUDAHOSTCXX ]]; then
		echo "${CUDAHOSTCXX}"
		return
	fi

	if ! command -v nvcc >/dev/null; then
		eerror "Could not find nvcc. Is the CUDA SDK installed?"
		die "nvcc not found"
	fi

	einfo "Trying to find working CUDA host compiler"

	if ! tc-is-gcc && ! tc-is-clang; then
		die "$(tc-get-compiler-type) compiler is not supported"
	fi

	# compiler with CHOST prefix
	# x86_64-pc-linux-gnu-g++
	local compiler

	# gcc or clang
	local compiler_type

	# major version of the current compiler. 15
	local compiler_version

	# cat/pkg of the compiler
	# sys-devel/gcc, llvm-core/clang
	local package

	# QPN of the package we are checking
	# sys-devel/gcc, <sys-devel/gcc-15
	local package_version

	# system compiler e.g. tc-getCXX plus version
	# used to skip rechecking, as we check NVCC_CCBIN first
	# x86_64-pc-linux-gnu-g++-15
	local NVCC_CCBIN_default

	compiler_type="$(tc-get-compiler-type)"
	compiler_version="$("${compiler_type}-major-version")"

	# try the default compiler first
	NVCC_CCBIN="$(tc-getCXX)"
	NVCC_CCBIN_default="${NVCC_CCBIN}-${compiler_version}"

	compiler="${NVCC_CCBIN/%-${compiler_version}}"

	# store the package so we can re-use it later
	if tc-is-gcc; then
		package="sys-devel/${compiler_type}"
	elif tc-is-clang; then
		package="llvm-core/${compiler_type}"
	else
		die "$(tc-get-compiler-type) compiler is not supported"
	fi

	package_version="${package}"

	ebegin "testing ${NVCC_CCBIN_default} (default)"

	while ! \
		nvcc \
			-v \
			-std=c++14 \
			-ccbin "${NVCC_CCBIN}" \
			- \
			-x cu \
			<<<"int main(){}" \
			&>> "${T:?}/cuda_get_host_compiler.log" ;
		do
		eend 1

		while true; do
			# prepare next version
			local package_version_next
			package_version_next="$(best_version "${package_version}")"

			if [[ -z "${package_version_next}" ]]; then
				eerror "Compiler lookup failed. Nothing installed matches: ${package_version}."
				eerror "You can use NVCC_CCBIN to specify the exact compiler to use."
				eerror "Check ${T}/cuda_get_host_compiler.log for details."
				die "Could not find a supported version of ${compiler}. Did not find \"${package_version}\". NVCC_CCBIN is unset."
			fi

			package_version="<${package_version_next}"

			NVCC_CCBIN="${compiler}-$(ver_cut 1 "${package_version/#<${package}-/}")"

			# skip the next version equals the already checked system default
			[[ "${NVCC_CCBIN}" != "${NVCC_CCBIN_default}" ]] && break
		done
		ebegin "testing ${NVCC_CCBIN}"
	done
	eend $?

	echo "${NVCC_CCBIN}"
	export NVCC_CCBIN
}

cuda_get_host_native_arch() {
	[[ -n ${CUDAARCHS} ]] && echo "${CUDAARCHS}"

	__nvcc_device_query || die "failed to query the native device"
}

pkg_setup() {
	llvm-r2_pkg_setup

	use python && python-single-r1_pkg_setup
}

src_prepare() {
	# clang-cuda needs to filter mfpmath
	if use clang-cuda ; then
		filter-mfpmath sse
		filter-mfpmath i386
	fi

	if use test && use optix; then
		cuda_src_prepare
	fi

	sed -e "/^install.*llvm_macros.cmake.*cmake/d" -i CMakeLists.txt || die
	sed -e "/install_targets ( libtestshade )/d" -i src/testshade/CMakeLists.txt || die

	# TODO needed for cuda-13
	sed -e "s/\+ptx50//g" -i src/liboslexec/llvm_util.cpp || die

	cmake_src_prepare
}

src_configure() {
	# -Werror=lto-type-mismatch
	# https://bugs.gentoo.org/875836
	# https://github.com/AcademySoftwareFoundation/OpenShadingLanguage/issues/1810
	filter-lto
	append-flags -fno-strict-aliasing

	# pick the highest we support
	local mysimd=()
	if use cpu_flags_x86_avx512f; then
		mysimd+=( avx512f )
	elif use cpu_flags_x86_avx2 ; then
		mysimd+=( avx2 )
		if use cpu_flags_x86_f16c ; then
			mysimd+=( f16c )
		fi
	elif use cpu_flags_x86_avx ; then
		mysimd+=( avx )
	elif use cpu_flags_x86_sse4_2 ; then
		mysimd+=( sse4.2 )
	elif use cpu_flags_x86_sse4_1 ; then
		mysimd+=( sse4.1 )
	elif use cpu_flags_x86_ssse3 ; then
		mysimd+=( ssse3 )
	elif use cpu_flags_x86_sse3 ; then
		mysimd+=( sse3 )
	elif use cpu_flags_x86_sse2 ; then
		mysimd+=( sse2 )
	fi

	local mybatched=()
	if use cpu_flags_x86_avx512f || use cpu_flags_x86_avx2 ; then
		if use cpu_flags_x86_avx512f ; then
			if use nofma; then
				mybatched+=(
					"b8_AVX512_noFMA"
					"b16_AVX512_noFMA"
				)
			fi
			mybatched+=(
				"b8_AVX512"
				"b16_AVX512"
			)
		fi
		if use cpu_flags_x86_avx2 ; then
			if use nofma; then
				mybatched+=(
					"b8_AVX2_noFMA"
				)
			fi
			mybatched+=(
				"b8_AVX2"
			)
		fi
	fi
	if use cpu_flags_x86_avx ; then
		mybatched+=(
			"b8_AVX"
		)
	fi

	# If no CPU SIMDs were used, completely disable them
	[[ -z "${mysimd[*]}" ]] && mysimd=("0")
	[[ -z "${mybatched[*]}" ]] && mybatched=("0")

	# This is currently needed on arm64 to get the NEON SIMD wrapper to compile the code successfully
	# Even if there are no SIMD features selected, it seems like the code will turn on NEON support if it is available.
	use arm64 && append-flags -flax-vector-conversions

	local mycmakeargs=(
		-DVERBOSE="no"
		-DCMAKE_POLICY_DEFAULT_CMP0146="OLD" # BUG FindCUDA

		-DCMAKE_INSTALL_DOCDIR="share/doc/${PF}"
		-DINSTALL_DOCS="$(usex doc)"
		-DUSE_CCACHE="no"
		-DLLVM_STATIC="no"
		-DOSL_BUILD_TESTS="$(usex test)"
		-DSTOP_ON_WARNING="no"
		-DUSE_LLVM_BITCODE="$(usex clang-cuda)"
		-DUSE_PARTIO="$(usex partio)"
		-DUSE_PYTHON="$(usex python)"
		-DUSE_SIMD="$(IFS=","; echo "${mysimd[*]}")"
		-DUSE_BATCHED="$(IFS=","; echo "${mybatched[*]}")"
		-DUSE_LIBCPLUSPLUS="$(usex libcxx)"
		-DUSE_QT="$(usex gui)"
		# -DUSE_FAST_MATH="no"
		# TODO
		-DVISIBILITY_INLINES_HIDDEN="no"
		-DCMAKE_CXX_VISIBILITY_PRESET="default"
	)

	if use debug; then
		mycmakeargs+=(
			-DVERBOSE="yes"
			-DVEC_REPORT="yes"
		)
	fi

	if use optix; then
		cuda_add_sandbox -w
		addwrite "/proc/self/task/"
		addpredict "/dev/char/"

		mycmakeargs+=(
			-DCUDA_OPT_FLAG_NVCC="$(get-flag O)"
			-DCUDA_OPT_FLAG_CLANG="$(get-flag O)"

			-DLLVM_COMPILE_FLAGS="-D_NV_RSQRT_SPECIFIER="
		)
	fi

	if use partio; then
		mycmakeargs+=(
			-Dpartio_DIR="${ESYSROOT}/usr"
		)
	fi

	if use python; then
		local -x OPENIMAGEIO_DEBUG=0
		mycmakeargs+=(
			-DOpenImageIO_ROOT="${ESYSROOT}/usr"
			-DPYTHON_VERSION="${EPYTHON#python}"
			-DPYTHON_SITE_DIR="$(python_get_sitedir)"
		)
	fi

	if use optix; then
		local -x CUDAHOSTCXX CUDAHOSTLD
		# TODO handle USE=cuda-clang
		CUDAHOSTCXX="$(cuda_get_host_compiler)"
		CUDAHOSTLD="$(tc-getCXX)"

		mycmakeargs+=(
			-DOSL_USE_OPTIX="yes"
			-DOptiX_FIND_QUIETLY="no"
			-DCUDA_FIND_QUIETLY="no"

			-DOPTIXHOME="${OPTIX_PATH:-${ESYSROOT}/opt/optix}"
			-DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH:-${ESYSROOT}/opt/cuda}"

			-DOSL_EXTRA_NVCC_ARGS="--compiler-bindir;${CUDAHOSTCXX}"
			-DCUDA_VERBOSE_BUILD="yes"
		)

		if has_version ">=dev-util/nvidia-cuda-toolkit-13"; then
			mycmakeargs+=(
				-DCUDA_TARGET_ARCH="sm_75"
			)
		fi
	fi

	cmake_src_configure
}

src_test() {
	# A bunch of tests only work when installed.
	# So install them into the temp directory now.
	DESTDIR="${T}" cmake_build install

	ln -s "${CMAKE_USE_DIR}/src/cmake/" "${BUILD_DIR}/src/cmake" || die

	local -x DEBUG CXXFLAGS LD_LIBRARY_PATH DIR OSL_DIR OSL_SOURCE_DIR PYTHONPATH
	DEBUG=1 # doubles the floating point tolerance so we avoid FMA related issues
	CXXFLAGS="-I${T}/usr/include"
	LD_LIBRARY_PATH="${T}/usr/$(get_libdir)"
	OSL_DIR="${T}/usr/$(get_libdir)/cmake/OSL"
	OSL_SOURCE_DIR="${S}"

	# local -x OSL_TESTSUITE_SKIP_DIFF=1
	local -x OPENIMAGEIO_DEBUG=0

	if use python; then
		PYTHONPATH="${BUILD_DIR}/lib/python/site-packages"
	fi

	if use optix; then
		cp \
			"${BUILD_DIR}/src/liboslexec/shadeops_cuda.ptx" \
			"${BUILD_DIR}/src/testrender/"{optix_raytracer,rend_lib_testrender}".ptx" \
			"${BUILD_DIR}/src/testshade/"{optix_grid_renderer,rend_lib_testshade}".ptx" \
			"${BUILD_DIR}/bin/" || die

		# NOTE this should go to cuda eclass
		cuda_add_sandbox -w
		addwrite "/proc/self/task/"
		addpredict "/dev/char/"
	fi

	local CMAKE_SKIP_TESTS=(
		"-broken$"

		batched

		# broken with in-tree <=dev-libs/optix-7.5.0 and out of date
		"^example-cuda"

		# doesn't handle parameters
		"^osl-imageio"
	)

	local myctestargs=(
		-LE '(render|optix)'
		# src/build-scripts/ci-test.bash
		'--force-new-ctest-process'
	)

	cmake_src_test

	# NOTE this should go to cuda eclass
	cuda_add_sandbox -w
	addwrite "/proc/self/task/"
	addpredict "/dev/char/"

	einfo ""
	einfo "testing render tests in isolation"
	einfo ""

	CMAKE_SKIP_TESTS=(
		# optix
		"^render-microfacet.optix.(fused|opt)$"
		"^render-raytypes.optix.(fused|opt)$"

		"^render-spi-thinlayer.optix"
		"^testoptix-noise.optix.opt$"

		"^render-uv.optix.(fused|opt)$"

		# render
		"^render-displacement.opt$"
		"^render-microfacet.opt$"
	)

	if ! tc-is-clang; then
		CMAKE_SKIP_TESTS+=(
			# render
			# small errors
			"^render-bunny.opt$"
			"^render-veachmis.opt$"
		)
	fi

	myctestargs=(
		-L "(render|optix)"
		# src/build-scripts/ci-test.bash
		'--force-new-ctest-process'
	)

	cmake_src_test
}

src_install() {
	cmake_src_install

	if use python; then
		python_optimize
	fi

	if [[ -d "${ED}/usr/build-scripts" ]]; then
		rm -vr "${ED}/usr/build-scripts" || die
	fi

	if use test; then
		rm \
			"${ED}/usr/bin/test"{render,shade{,_dso}} \
			|| die
	fi

	if use amd64; then
		find "${ED}/usr/$(get_libdir)" -type f  -name 'lib_*_oslexec.so' -print0 \
			| while IFS= read -r -d $'\0' batched_lib; do
			patchelf --set-soname "$(basename "${batched_lib}")" "${batched_lib}" || die
		done
	fi
}
