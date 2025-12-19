# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# shellcheck disable=SC2317

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
inherit check-reqs desktop unpacker python-r1

DRIVER_PV="560.35.03"
# grep -P "unsupported (GNU|clang) version" builds/cuda_nvcc/targets/x86_64-linux/include/crt/host_config.h
GCC_MAX_VER="13"
CLANG_MAX_VER="18"

DESCRIPTION="NVIDIA CUDA Toolkit (compiler and friends)"
HOMEPAGE="https://developer.nvidia.com/cuda-zone"
SRC_URI="
	amd64? (
		https://developer.download.nvidia.com/compute/cuda/${PV}/local_installers/cuda_${PV}_${DRIVER_PV}_linux.run
	)
	arm64? (
		https://developer.download.nvidia.com/compute/cuda/${PV}/local_installers/cuda_${PV}_${DRIVER_PV}_linux_sbsa.run
	)
"
S="${WORKDIR}"

LICENSE="NVIDIA-CUDA"
SLOT="${PV}"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="debugger examples nsight profiler rdma vis-profiler sanitizer"
RESTRICT="bindist mirror strip test"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# ./cuda-installer --silent --toolkit --no-opengl-libs --no-drm
# since CUDA 11, the bundled toolkit driver (== ${DRIVER_PV}) and the
# actual required minimum driver version are different.
RDEPEND="${PYTHON_DEPS}
	|| (
		<sys-devel/gcc-$(( GCC_MAX_VER + 1 ))_pre[cxx]
		<llvm-core/clang-$(( CLANG_MAX_VER + 1 ))_pre
	)
	sys-process/numactl
	examples? (
		media-libs/freeglut
		media-libs/glu
	)
	rdma? ( sys-cluster/rdma-core )
	vis-profiler? (
		virtual/jre:1.8
	)
	nsight? (
		app-crypt/mit-krb5
		dev-libs/libpfm
		dev-libs/openssl-compat:1.1.1
		dev-qt/qtwayland:6
		media-libs/gst-plugins-base
		media-libs/tiff-compat:4
		sys-cluster/ucx
		sys-libs/zlib

		dev-libs/nss
		x11-libs/libXcomposite
		x11-libs/libXdamage
		x11-libs/libXtst
		x11-libs/libxkbfile
		x11-libs/libxshmfence
	)
"
BDEPEND="
	dev-python/defusedxml[${PYTHON_USEDEP}]
	nsight? ( dev-util/patchelf )
"

QA_PREBUILT="opt/cuda-${PV}/*"
CHECKREQS_DISK_BUILD="14G"

pkg_setup() {
	check-reqs_pkg_setup
	python_setup
}

src_prepare() {
	default

	# safe some space, we don't need the driver
	rm builds/NVIDIA-Linux-*-"${DRIVER_PV}".run || die
}

src_install() {
	local narch
	if use amd64; then
		narch=x86_64
	elif use arm64; then
		narch=sbsa
	fi

	local -x SKIP_COMPONENTS=(
		"nsight"        # eclipse plugin
		"cuda-gdb-src"  # not used
		"Documentation" # obsolete

		# Toolkit # always install
		# 	Libraries # USE=libs
		# 		Development # USE=dev
		# 		Runtime # USE=runtime
		# 	Tools # USE=tools
		# 		Command_Line_Tools # USE=cli
		# 		Visual_Tools  # USE=gui
		# 	Compiler # use compiler
		# Demo_Suite # use examples
	)

	! use debugger     && SKIP_COMPONENTS+=( "cuda-gdb" )
	! use examples     && SKIP_COMPONENTS+=( "Demo_Suite" )
	! use profiler     && SKIP_COMPONENTS+=( "cuda-cupti" "cuda-profiler-api" "nvprof" )
	! use sanitizer    && SKIP_COMPONENTS+=( "compute-sanitizer" )
	! use vis-profiler && SKIP_COMPONENTS+=( "nvvp" )

	local ldpathextradirs pathextradirs
	local cudadir="/opt/cuda-${PV}"
	local ecudadir="${EPREFIX}${cudadir}"
	dodir "${cudadir}"
	into "${cudadir}"

	dofile() {
		local _DESTDIR="$(dirname "${1}")"

		if [[ "${_DESTDIR}" == '.' ]]; then
			_DESTDIR="${cudadir}/"
		else
			_DESTDIR="${cudadir}/${_DESTDIR%/}/"
		fi

		[[ $# -gt 1  ]] && _DESTDIR+="${2%/}/"

		insinto "${_DESTDIR}"

		for file in ${1}; do
			if [[ -f "${ED}${_DESTDIR}$(basename "${file}")" ]]; then
				continue
			fi

			ebegin "${_DESTDIR}$(basename "${file}") installing" # {{{
			# local opts=
			# [[ -d "${file}" ]] && opts="-r"

			# doins ${opts} "${file}"
			doins -r "${file}"
			eend $? #}}}

			readarray -t fs < <( find "${file}" -type f -executable )
			for f in "${fs[@]}"; do
				local _DESTFILE _SRCFILE
				_SRCFILE="$(pwd)/${f}"
				_DESTFILE="${_DESTDIR}$( realpath -s --relative-to="$(dirname "${1}")" "${f}" )"

				einfo "${_DESTFILE} setting permissions"
				chmod --reference="${f}" "${ED}${_DESTFILE}" \
					|| die "failed to copy permissions from ${_SRCFILE} to ${ED}${_DESTFILE}"
			done
		done
	}

	dopcfile() {
		dodir "${ecudadir}/pkgconfig"
		cat > "${D}${ecudadir}/pkgconfig/${1}-${2}.pc" <<-EOF || die
			cudaroot=${ecudadir}
			libdir=\${cudaroot}/targets/${narch}-linux/lib${4}
			includedir=\${cudaroot}/targets/${narch}-linux/include

			Name: ${1}
			Description: ${3}
			Version: ${2}
			Libs: -L\${libdir} -l${1}
			Cflags: -I\${includedir}
		EOF
	}

	dodesktopFile() {
		[[ $# -eq 0 ]] && return

		local name ver
		if [[ "$(dirname "${6}")" == "bin" ]]; then
			ver="${PV}"
		else
			ver="$(echo "${6}" | cut -d '/' -f 1 | rev | cut -d '-' -f 1 | rev)"
		fi
		name="${1}-${ver}"

		newmenu - "${name}.desktop" <<-EOF || die
			[Desktop Entry]
			Type=Application
			Name=${2} ${ver}
			GenericName=${2}
			Icon=${ecudadir}/${5}
			Exec=env WAYLAND_DISPLAY= ${ecudadir}/${6}
			TryExec=${ecudadir}/${7}
			Keywords=${4}
			X-AppInstall-Keywords=${4}
			X-GNOME-Keywords=${4}
			Terminal=false
			Categories=${3}
		EOF
	}

	fix_executable_bit=(
		cuda_cupti/extras/CUPTI/samples/pc_sampling_utility/pc_sampling_utility_helper.h
		cuda_cupti/extras/CUPTI/samples/pc_sampling_continuous/libpc_sampling_continuous.pl
		cuda_nvvp/libnvvp/icon.xpm
		cuda_opencl/targets/x86_64-linux/include/CL/cl.hpp
		libcufile/gds/tools/run_gdsio.cfg
		libcufile/targets/x86_64-linux/lib/libcufile_rdma_static.a
		libcufile/targets/x86_64-linux/lib/libcufile_static.a
	)
	for file in "${fix_executable_bit[@]}"; do
		[[ ! -x ${file/#/builds/} ]] && eqawarn "$file $(ls -lh "${file/#/builds/}")"
	done
	chmod -x "${fix_executable_bit[@]/#/builds/}" || die

	if ! has Toolkit "${SKIP_COMPONENTS[@]}"; then # "CUDA Toolkit 12.6"
		cd "${S}/builds/" || die "cd ${S}/builds/ failed"

		dofile "version.json"
		if ! has Libraries "${SKIP_COMPONENTS[@]}"; then # "CUDA Libraries 12.6"
			if ! has Development "${SKIP_COMPONENTS[@]}"; then # "CUDA Development 12.6"
				if ! has cuda-cccl "${SKIP_COMPONENTS[@]}"; then # "cuda-cccl"
					cd "${S}/builds/cuda_cccl/" || die "cd ${S}/builds/cuda_cccl/ failed"

					dofile "targets/${narch}-linux/include/*"
					dofile "targets/${narch}-linux/lib/*"
				fi
				if ! has cuda-cudart-dev "${SKIP_COMPONENTS[@]}"; then # "cuda-cudart-dev"
					cd "${S}/builds/cuda_cudart/" || die "cd ${S}/builds/cuda_cudart/ failed"

					dofile "targets/${narch}-linux/lib/*.so"
					dofile "targets/${narch}-linux/lib/*.a"
					dofile "targets/${narch}-linux/include/*"
					dopcfile "cudart" "12.6" "CUDA Runtime Library"
				fi
				if ! has cuda-driver-dev "${SKIP_COMPONENTS[@]}"; then # "cuda-driver-dev"
					cd "${S}/builds/cuda_cudart/" || die "cd ${S}/builds/cuda_cudart/ failed"

					dofile "targets/${narch}-linux/lib/stubs/libcuda.so"
					dopcfile "cuda" "12.6" "CUDA Driver Library" "/stubs/"
				fi
				if ! has cuda-nvml-dev "${SKIP_COMPONENTS[@]}"; then # "cuda-nvml-dev"
					cd "${S}/builds/cuda_nvml_dev/" || die "cd ${S}/builds/cuda_nvml_dev/ failed"

					dofile "targets/${narch}-linux/lib/stubs/libnvidia-ml.a"
					dofile "targets/${narch}-linux/lib/stubs/libnvidia-ml.so"
					dofile "targets/${narch}-linux/include/nvml.h"
					dofile "nvml"
					dopcfile "nvidia-ml" "12.6" "NVML" "/stubs/"
				fi
				if ! has cuda-nvrtc-dev "${SKIP_COMPONENTS[@]}"; then # "cuda-nvrtc-dev"
					cd "${S}/builds/cuda_nvrtc/" || die "cd ${S}/builds/cuda_nvrtc/ failed"

					dofile "targets/${narch}-linux/lib/*.so"
					dofile "targets/${narch}-linux/lib/*.a"
					dofile "targets/${narch}-linux/lib/stubs/*"
					dofile "targets/${narch}-linux/include/*"
					dopcfile "nvrtc" "12.6" "A runtime compilation library for CUDA C++"
				fi
				if ! has cuda-opencl-dev "${SKIP_COMPONENTS[@]}"; then # "cuda-opencl-dev"
					cd "${S}/builds/cuda_opencl/" || die "cd ${S}/builds/cuda_opencl/ failed"

					dofile "targets/${narch}-linux/lib/*.so"
					dofile "targets/${narch}-linux/include/CL/*"
					dopcfile "opencl" "12.6" "CUDA Runtime Library"
				fi
				if ! has cuda-profiler-api "${SKIP_COMPONENTS[@]}"; then # "cuda-profiler-api"
					cd "${S}/builds/cuda_profiler_api/" || die "cd ${S}/builds/cuda_profiler_api/ failed"

					dofile "targets/${narch}-linux/include/cuda_profiler_api.h"
					dofile "targets/${narch}-linux/include/cudaProfiler.h"
				fi
				if ! has libcublas-dev "${SKIP_COMPONENTS[@]}"; then # "libcublas-dev"
					cd "${S}/builds/libcublas/" || die "cd ${S}/builds/libcublas/ failed"

					dofile "targets/${narch}-linux/lib/libcublas.so"
					dofile "targets/${narch}-linux/lib/libcublas_static.a"
					dofile "targets/${narch}-linux/lib/libcublasLt.so"
					dofile "targets/${narch}-linux/lib/libcublasLt_static.a"
					dofile "targets/${narch}-linux/lib/libnvblas.so"
					dofile "targets/${narch}-linux/lib/stubs/libcublas.so"
					dofile "targets/${narch}-linux/lib/stubs/libcublasLt.so"
					dofile "targets/${narch}-linux/include/nvblas.h"
					dofile "targets/${narch}-linux/include/cublas_api.h"
					dofile "targets/${narch}-linux/include/cublas.h"
					dofile "targets/${narch}-linux/include/cublas_v2.h"
					dofile "targets/${narch}-linux/include/cublasLt.h"
					dofile "targets/${narch}-linux/include/cublasXt.h"
					dofile "src/fortran_thunking.c"
					dofile "src/fortran_common.h"
					dofile "src/fortran.h"
					dofile "src/fortran_thunking.h"
					dofile "src/fortran.c"
					dopcfile "cublas" "12" "CUDA Basic Linear Algebra Subprograms"
				fi
				if ! has libcufft-dev "${SKIP_COMPONENTS[@]}"; then # "libcufft-dev"
					cd "${S}/builds/libcufft/" || die "cd ${S}/builds/libcufft/ failed"

					dofile "targets/${narch}-linux/lib/libcufft*.so"
					dofile "targets/${narch}-linux/lib/stubs/libcufft*.so*"
					dofile "targets/${narch}-linux/lib/libcufft*_static.a"
					dofile "targets/${narch}-linux/lib/libcufft_static_nocallback.a"
					dofile "targets/${narch}-linux/include/cufft*"
					dofile "targets/${narch}-linux/include/cudalibxt.h"
					dopcfile "cufft" "11.3" "CUDA Fast Fourier Transform"
					dopcfile "cufftw" "11.3" "CUDA Fast Fourier Transform Wide"
				fi
				if ! has libcufile-dev "${SKIP_COMPONENTS[@]}"; then # "libcufile-dev"
					cd "${S}/builds/libcufile/" || die "cd ${S}/builds/libcufile/ failed"

					dofile "targets/${narch}-linux/include/cufile.h"
					dofile "targets/${narch}-linux/lib/libcufile.so"
					dofile "targets/${narch}-linux/lib/libcufile_rdma.so"
					dofile "targets/${narch}-linux/lib/libcufile_static.a"
					dofile "targets/${narch}-linux/lib/libcufile_rdma_static.a"
					dofile "gds/cufile.json"
					dofile "gds/EULA.txt"
					dofile "gds/doc/**"
					dofile "gds/man/man3/**"
					dofile "gds/tools/**"
					dofile "gds-12.6/**"
					dopcfile "cufile" "1.11" "NVIDIA GPUDirect Storage Library"
				fi
				if ! has libcurand-dev "${SKIP_COMPONENTS[@]}"; then # "libcurand-dev"
					cd "${S}/builds/libcurand/" || die "cd ${S}/builds/libcurand/ failed"

					dofile "targets/${narch}-linux/lib/libcurand.so"
					dofile "targets/${narch}-linux/lib/stubs/libcurand.so*"
					dofile "targets/${narch}-linux/lib/libcurand_static.a"
					dofile "targets/${narch}-linux/include/curand*"
					dopcfile "curand" "10.3" "CUDA Random Number Generation Library"
				fi
				if ! has libcusolver-dev "${SKIP_COMPONENTS[@]}"; then # "libcusolver-dev"
					cd "${S}/builds/libcusolver/" || die "cd ${S}/builds/libcusolver/ failed"

					dofile "targets/${narch}-linux/lib/libcusolver.so"
					dofile "targets/${narch}-linux/lib/libcusolverMg.so"
					dofile "targets/${narch}-linux/lib/stubs/libcusolver*"
					dofile "targets/${narch}-linux/lib/stubs/libcusolverMg*"
					dofile "targets/${narch}-linux/lib/libcusolver*_static.a"
					dofile "targets/${narch}-linux/lib/libmetis_static.a"
					dofile "targets/${narch}-linux/include/cusolver*"
					dopcfile "cusolver" "11.7" "A LAPACK-like library on dense and sparse linear algebra"
				fi
				if ! has libcusparse-dev "${SKIP_COMPONENTS[@]}"; then # "libcusparse-dev"
					cd "${S}/builds/libcusparse/" || die "cd ${S}/builds/libcusparse/ failed"

					dofile "targets/${narch}-linux/lib/libcusparse.so*"
					dofile "targets/${narch}-linux/lib/stubs/libcusparse.so*"
					dofile "targets/${narch}-linux/lib/libcusparse_static.a"
					dofile "targets/${narch}-linux/include/cusparse*"
					dofile "src/cusparse_fortran*"
					dopcfile "cusparse" "12.5" "CUDA Sparse Matrix Library"
				fi
				if ! has libnpp-dev "${SKIP_COMPONENTS[@]}"; then # "libnpp-dev"
					cd "${S}/builds/libnpp/" || die "cd ${S}/builds/libnpp/ failed"

					dofile "targets/${narch}-linux/lib/libnpp*.so"
					dofile "targets/${narch}-linux/lib/stubs/libnpp*.so*"
					dofile "targets/${narch}-linux/lib/libnpp*_static.a"
					dofile "targets/${narch}-linux/include/npp*"
					dopcfile "npps" "12.3" "NVIDIA Performance Primitives - Signal Processing"
					dopcfile "nppi" "12.3" "NVIDIA Performance Primitives - Image Processing"
					dopcfile "nppial" "12.3" "NVIDIA Performance Primitives - Image Processing - Arithmetic and Logic"
					dopcfile "nppicc" "12.3" "NVIDIA Performance Primitives - Image Processing - Color Conversion"
					dopcfile "nppicom" "12.3" "NVIDIA Performance Primitives - Image Processing - Compression"
					dopcfile "nppidei" "12.3" "NVIDIA Performance Primitives - Image Processing - DEI"
					dopcfile "nppif" "12.3" "NVIDIA Performance Primitives - Image Processing - Filters"
					dopcfile "nppig" "12.3" "NVIDIA Performance Primitives - Image Processing - Geometry"
					dopcfile "nppim" "12.3" "NVIDIA Performance Primitives - Image Processing - Morphological"
					dopcfile "nppist" "12.3" "NVIDIA Performance Primitives - Image Processing - Statistic and Linear"
					dopcfile "nppisu" "12.3" "NVIDIA Performance Primitives - Image Processing - Support and Data Exchange"
					dopcfile "nppitc" "12.3" "NVIDIA Performance Primitives - Image Processing - Threshold and Compare"
					dopcfile "nppc" "12.3" "NVIDIA Performance Primitives - Core"
				fi
				if ! has libnvfatbin-dev "${SKIP_COMPONENTS[@]}"; then # "libnvfatbin-dev"
					cd "${S}/builds/libnvfatbin/" || die "cd ${S}/builds/libnvfatbin/ failed"

					dofile "targets/${narch}-linux/lib/libnvfatbin.so"
					dofile "targets/${narch}-linux/lib/libnvfatbin_static.a"
					dofile "targets/${narch}-linux/lib/stubs/libnvfatbin.so"
					dofile "targets/${narch}-linux/include/nvFatbin*"
					dopcfile "nvfatbin" "12.6" "NVIDIA fatbin Library"
				fi
				if ! has libnvjitlink-dev "${SKIP_COMPONENTS[@]}"; then # "libnvjitlink-dev"
					cd "${S}/builds/libnvjitlink/" || die "cd ${S}/builds/libnvjitlink/ failed"

					dofile "targets/${narch}-linux/lib/*.so"
					dofile "targets/${narch}-linux/lib/*.a"
					dofile "targets/${narch}-linux/lib/stubs/*"
					dofile "targets/${narch}-linux/include/*"
					dopcfile "nvjitlink" "12.6" "NVIDIA JIT Link Library"
				fi
				if ! has libnvjpeg-dev "${SKIP_COMPONENTS[@]}"; then # "libnvjpeg-dev"
					cd "${S}/builds/libnvjpeg/" || die "cd ${S}/builds/libnvjpeg/ failed"

					dofile "targets/${narch}-linux/lib/libnvjpeg.so"
					dofile "targets/${narch}-linux/lib/stubs/libnvjpeg.so*"
					dofile "targets/${narch}-linux/lib/libnvjpeg_static.a"
					dofile "targets/${narch}-linux/include/nvjpeg*"
					dopcfile "nvjpeg" "12.3" "NVIDIA JPEG Library"
				fi
			fi
			if ! has Runtime "${SKIP_COMPONENTS[@]}"; then # "CUDA Runtime 12.6"
				if ! has cuda-cudart "${SKIP_COMPONENTS[@]}"; then # "cuda-cudart"
					cd "${S}/builds/cuda_cudart/" || die "cd ${S}/builds/cuda_cudart/ failed"

					dofile "targets/${narch}-linux/lib/*.so.*"
				fi
				if ! has cuda-nvrtc "${SKIP_COMPONENTS[@]}"; then # "cuda-nvrtc"
					cd "${S}/builds/cuda_nvrtc/" || die "cd ${S}/builds/cuda_nvrtc/ failed"

					dofile "targets/${narch}-linux/lib/*.so.*"
				fi
				if ! has cuda-opencl "${SKIP_COMPONENTS[@]}"; then # "cuda-opencl"
					cd "${S}/builds/cuda_opencl/" || die "cd ${S}/builds/cuda_opencl/ failed"

					dofile "targets/${narch}-linux/lib/*.so.*"
				fi
				if ! has libcublas12 "${SKIP_COMPONENTS[@]}"; then # "libcublas12"
					cd "${S}/builds/libcublas/" || die "cd ${S}/builds/libcublas/ failed"

					dofile "targets/${narch}-linux/lib/libcublas.so.*"
					dofile "targets/${narch}-linux/lib/libcublasLt.so.*"
					dofile "targets/${narch}-linux/lib/libnvblas.so.*"
				fi
				if ! has libcufft "${SKIP_COMPONENTS[@]}"; then # "libcufft"
					cd "${S}/builds/libcufft/" || die "cd ${S}/builds/libcufft/ failed"

					dofile "targets/${narch}-linux/lib/libcufft*.so.*"
				fi
				if ! has libcufile "${SKIP_COMPONENTS[@]}"; then # "libcufile"
					cd "${S}/builds/libcufile/" || die "cd ${S}/builds/libcufile/ failed"

					dofile "targets/${narch}-linux/include/cufile.h"
					dofile "targets/${narch}-linux/lib/libcufile.so.*"
					dofile "targets/${narch}-linux/lib/libcufile_rdma.so.*"
				fi
				if ! has libcurand "${SKIP_COMPONENTS[@]}"; then # "libcurand"
					cd "${S}/builds/libcurand/" || die "cd ${S}/builds/libcurand/ failed"

					dofile "targets/${narch}-linux/lib/libcurand.so.*"
				fi
				if ! has libcusolver "${SKIP_COMPONENTS[@]}"; then # "libcusolver"
					cd "${S}/builds/libcusolver/" || die "cd ${S}/builds/libcusolver/ failed"

					dofile "targets/${narch}-linux/lib/libcusolver.so.*"
					dofile "targets/${narch}-linux/lib/libcusolverMg.so.*"
				fi
				if ! has libcusparse "${SKIP_COMPONENTS[@]}"; then # "libcusparse"
					cd "${S}/builds/libcusparse/" || die "cd ${S}/builds/libcusparse/ failed"

					dofile "targets/${narch}-linux/lib/libcusparse.so.*"
				fi
				if ! has libnpp "${SKIP_COMPONENTS[@]}"; then # "libnpp"
					cd "${S}/builds/libnpp/" || die "cd ${S}/builds/libnpp/ failed"

					dofile "targets/${narch}-linux/lib/libnpp*.so.*"
				fi
				if ! has libnvfatbin "${SKIP_COMPONENTS[@]}"; then # "libnvfatbin"
					cd "${S}/builds/libnvfatbin/" || die "cd ${S}/builds/libnvfatbin/ failed"

					dofile "targets/${narch}-linux/lib/libnvfatbin.so.*"
				fi
				if ! has libnvjitlink "${SKIP_COMPONENTS[@]}"; then # "libnvjitlink"
					cd "${S}/builds/libnvjitlink/" || die "cd ${S}/builds/libnvjitlink/ failed"

					dofile "targets/${narch}-linux/lib/*.so.*"
				fi
				if ! has libnvjpeg "${SKIP_COMPONENTS[@]}"; then # "libnvjpeg"
					cd "${S}/builds/libnvjpeg/" || die "cd ${S}/builds/libnvjpeg/ failed"

					dofile "targets/${narch}-linux/lib/libnvjpeg.so.*"
				fi
			fi
		fi
		if ! has Tools "${SKIP_COMPONENTS[@]}"; then # "CUDA Tools 12.6"
			if ! has Command_Line_Tools "${SKIP_COMPONENTS[@]}"; then # "CUDA Command Line Tools 12.6"
				if ! has cuda-cupti "${SKIP_COMPONENTS[@]}"; then # "cuda-cupti"
					cd "${S}/builds/cuda_cupti/" || die "cd ${S}/builds/cuda_cupti/ failed"

					dofile "extras/CUPTI"
				fi
				if ! has cuda-gdb "${SKIP_COMPONENTS[@]}"; then # "cuda-gdb"
					cd "${S}/builds/cuda_gdb/" || die "cd ${S}/builds/cuda_gdb/ failed"

					dofile "bin"
					dofile "extras/Debugger"
					dofile "share"
				fi
				if ! has cuda-gdb-src "${SKIP_COMPONENTS[@]}"; then # "cuda-gdb-src"
					cd "${S}/builds/cuda_gdb/" || die "cd ${S}/builds/cuda_gdb/ failed"

					dofile "extras/cuda-gdb*.src.tar.gz"
				fi
				if ! has nvdisasm "${SKIP_COMPONENTS[@]}"; then # "nvdisasm"
					cd "${S}/builds/cuda_nvdisasm/" || die "cd ${S}/builds/cuda_nvdisasm/ failed"

					dofile "bin/nvdisasm"
				fi
				if ! has nvprof "${SKIP_COMPONENTS[@]}"; then # "nvprof"
					cd "${S}/builds/cuda_nvprof/" || die "cd ${S}/builds/cuda_nvprof/ failed"

					dofile "bin/nvprof"
					dofile "targets/${narch}-linux/lib/libcuinj*"
					dofile "targets/${narch}-linux/lib/libaccinj*"
					dopcfile "cuinj64" "12.6" "CUDA 64-bit Injection Library"
					dopcfile "accinj64" "12.6" "OpenACC 64-bit Injection Library"
				fi
				if ! has nvtx "${SKIP_COMPONENTS[@]}"; then # "nvtx"
					cd "${S}/builds/cuda_nvtx/" || die "cd ${S}/builds/cuda_nvtx/ failed"

					dofile "targets/${narch}-linux/lib/*"
					dofile "targets/${narch}-linux/include/*"
					dopcfile "nvToolsExt" "12.6" "NVIDIA Tools Extension"
				fi
				if ! has compute-sanitizer "${SKIP_COMPONENTS[@]}"; then # "compute-sanitizer"
					cd "${S}/builds/cuda_sanitizer_api/" || die "cd ${S}/builds/cuda_sanitizer_api/ failed"

					dofile "compute-sanitizer"
					if ! has compute-sanitizer-integration "${SKIP_COMPONENTS[@]}"; then # "compute-sanitizer-integration"
						cd "${S}/builds/integration/Sanitizer/" || die "cd ${S}/builds/integration/Sanitizer/ failed"

						dofile "*" "bin"
					fi
				fi
			fi
			if ! has Visual_Tools "${SKIP_COMPONENTS[@]}"; then # "CUDA Visual Tools 12.6"
				if ! has nvvp "${SKIP_COMPONENTS[@]}"; then # "nvvp"
					cd "${S}/builds/cuda_nvvp/" || die "cd ${S}/builds/cuda_nvvp/ failed"

					dofile "libnvvp"
					dofile "bin/nvvp"
					dodesktopFile \
						"nvvp" \
						"NVIDIA Visual Profiler" \
						"Development;Profiling;ParallelComputing" \
						"nvvp;cuda;gpu;nsight;" \
						"libnvvp/icon.xpm" \
						"bin/nvvp" \
						"bin/nvvp"
				fi
				if ! has nsight-compute "${SKIP_COMPONENTS[@]}"; then # "nsight-compute"
					cd "${S}/builds/nsight_compute/" || die "cd ${S}/builds/nsight_compute/ failed"

					dofile "*" "nsight-compute-2024.3.2"
					dodesktopFile \
						"nsight-compute" \
						"Nsight Compute" \
						"Development;Profiling;ParallelComputing" \
						"cuda;gpu;nvidia;nsight;" \
						"nsight-compute-2024.3.2/host/linux-desktop-glibc_2_11_3-x64/ncu-ui.png" \
						"nsight-compute-2024.3.2/host/linux-desktop-glibc_2_11_3-x64/ncu-ui" \
						"nsight-compute-2024.3.2/host/linux-desktop-glibc_2_11_3-x64/ncu-ui"
					if ! has cuda-nsight-compute-integration "${SKIP_COMPONENTS[@]}"; then # "cuda-nsight-compute-integration"
						cd "${S}/builds/integration/nsight-compute/" || die "cd ${S}/builds/integration/nsight-compute/ failed"

						dofile "*" "bin"
					fi
				fi
				if ! has nsight-systems "${SKIP_COMPONENTS[@]}"; then # "nsight-systems"
					cd "${S}/builds/nsight_systems/" || die "cd ${S}/builds/nsight_systems/ failed"

					dofile "*" "nsight-systems-2024.5.1"
					dodesktopFile \
						"nsight-systems" \
						"Nsight Systems" \
						"Development;Profiling;ParallelComputing" \
						"cuda;gpu;nvidia;nsight;" \
						"nsight-systems-2024.5.1/host-linux-x64/nsight-sys.png" \
						"nsight-systems-2024.5.1/host-linux-x64/nsight-sys" \
						"nsight-systems-2024.5.1/host-linux-x64/nsight-sys"
					if ! has cuda-nsight-systems-integration "${SKIP_COMPONENTS[@]}"; then # "cuda-nsight-systems-integration"
						cd "${S}/builds/integration/nsight-systems/" || die "cd ${S}/builds/integration/nsight-systems/ failed"

						dofile "*" "bin"
					fi
				fi
			fi
		fi
		if ! has Compiler "${SKIP_COMPONENTS[@]}"; then # "CUDA Compiler 12.6"
			if ! has cuda-cuobjdump "${SKIP_COMPONENTS[@]}"; then # "cuda-cuobjdump"
				cd "${S}/builds/cuda_cuobjdump/" || die "cd ${S}/builds/cuda_cuobjdump/ failed"

				dofile "bin/cuobjdump"
			fi
			if ! has cuda-cuxxfilt "${SKIP_COMPONENTS[@]}"; then # "cuda-cuxxfilt"
				cd "${S}/builds/cuda_cuxxfilt/" || die "cd ${S}/builds/cuda_cuxxfilt/ failed"

				dofile "bin/cu++filt"
				dofile "targets/${narch}-linux/lib/*"
				dofile "targets/${narch}-linux/include/*"
			fi
			if ! has cuda-nvcc "${SKIP_COMPONENTS[@]}"; then # "cuda-nvcc"
				cd "${S}/builds/cuda_nvcc/" || die "cd ${S}/builds/cuda_nvcc/ failed"

				dofile "targets/${narch}-linux/include/*.h"
				dofile "targets/${narch}-linux/lib/*"
				dofile "bin/*"
			fi
			if ! has cuda-nvvm "${SKIP_COMPONENTS[@]}"; then # "cuda-nvvm"
				cd "${S}/builds/cuda_nvcc/" || die "cd ${S}/builds/cuda_nvcc/ failed"

				dofile "nvvm*"
			fi
			if ! has cuda-crt "${SKIP_COMPONENTS[@]}"; then # "cuda-crt"
				cd "${S}/builds/cuda_nvcc/" || die "cd ${S}/builds/cuda_nvcc/ failed"

				dofile "bin/crt"
				dofile "targets/${narch}-linux/include/crt"
			fi
			if ! has cuda-nvprune "${SKIP_COMPONENTS[@]}"; then # "cuda-nvprune"
				cd "${S}/builds/cuda_nvprune/" || die "cd ${S}/builds/cuda_nvprune/ failed"

				dofile "bin/nvprune"
			fi
		fi
	fi
	if ! has Demo_Suite "${SKIP_COMPONENTS[@]}"; then # "CUDA Demo Suite 12.6"
		cd "${S}/builds/cuda_demo_suite/" || die "cd ${S}/builds/cuda_demo_suite/ failed"

		dofile "extras/demo_suite"
	fi

	if use debugger; then
		if [[ -d "${ED}/${cudadir}/extras/Debugger/lib64" ]]; then
				eqawarn "${ED}/${cudadir}/extras/Debugger/lib64"
		# 	rmdir "${ED}/${cudadir}/extras/Debugger/lib64" || die
		fi

		# remove all so we can reinstall the ones we want
		rm "${ED}/${cudadir}/bin/cuda-gdb-"*"-tui" || die

		cd "${S}" || die

		into "${cudadir}"

		install_cuda-gdb-tui() {
			dobin "builds/cuda_gdb/bin/cuda-gdb-${EPYTHON}-tui"
		}

		python_foreach_impl install_cuda-gdb-tui

		for tui in "builds/cuda_gdb/bin/cuda-gdb-"*"-tui"; do
			tui_name=$(basename "${tui}")
		  if [[ ! -f "${ED}/${cudadir}/bin/${tui_name}" ]]; then
				sed -e "/${tui_name}\"/d" -i "${ED}/${cudadir}/bin/cuda-gdb" || die
			fi
		done
	fi

	if use nsight; then
		local ncu_dir_host ncu_dir_target nsys_dir_host nsys_dir_target
		if use amd64; then
			ncu_dir_host=glibc_2_11_3-x64
			ncu_dir_target=glibc_2_11_3-x64
			nsys_dir_host=x64
			nsys_dir_target=x64
		elif use arm64; then
			ncu_dir_host=t210-a64
			ncu_dir_target=t210-a64
			nsys_dir_host=armv8
			nsys_dir_target=sbsa-armv8
		fi

		local ncu_dir nsys_dir
		ncu_dir=$( ls -d "${ED}${cudadir}/nsight-compute-"* || die )
		nsys_dir=$( ls -d "${ED}${cudadir}/nsight-systems-"* || die )

		sed \
			-e "s#${nsys_dir_host}/nsight-sys#${nsys_dir_host}/nsys-ui#g" \
			-i "${ED}/usr/share/applications/nsight-systems-"*.desktop \
			|| die

		readarray -t rpath_libs < <(find "${ED}${cudadir}/"nsight* -name libparquet.so -o -name libarrow.so )
		for rpath_lib in "${rpath_libs[@]}"; do
			ebegin "fixing rpath for ${rpath_lib}"
			patchelf --set-rpath '$ORIGIN' "${rpath_lib}"
			eend $?
		done

		local libs=()
		# remove rdma libs (unless USE=rdma)
		if ! use rdma; then
			libs+=(
				"${ncu_dir}/host/target-linux-${nsys_dir_host}/CollectX"
				"${nsys_dir}/target-linux-${nsys_dir_host}/CollectX"
			)
		fi

		# remove foreign archs (triggers SONAME warning, #749903)
		# for dir in "${ncu_dir}/target/"*; do
		# 	einfo "${dir}"
		# 	einfo "${ncu_dir}/target/${ncu_dir_target}"
		# 	[[ "${dir}" == "${ncu_dir}/target/${ncu_dir_target}" ]] && continue
		# 	libs+=( "${dir}" )
		# done

		libs+=(
		# unbundle libstdc++
			"${nsys_dir}/host-linux-${nsys_dir_host}/libstdc++.so.6"
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libstdc++.so.6"

		# unbundle openssl
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/lib"{crypto,ssl}".so"*
			"${nsys_dir}/host-linux-${nsys_dir_host}/lib"{crypto,ssl}".so"*

		# 	"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libssh.so"*
		# 	"${nsys_dir}/host-linux-${nsys_dir_host}/libssh.so"*
		)
		# unbundle libpfm
		if use amd64; then
			libs+=(
				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libpfm.so"*
				"${nsys_dir}/host-linux-${nsys_dir_host}/libpfm.so"*
			)
		fi

		libs+=(
			"${ncu_dir}/"*/*"/python/bin/python"
			"${nsys_dir}/"*"/python/bin/python"

			"${ncu_dir}/"*/*"/sqlite3"
			"${nsys_dir}/"*"/sqlite3"
		)

		for lib in "${libs[@]}"; do
			ebegin "removing ${lib}"
			rm -r "${lib}"
			eend $? || die "failed to remove ${lib}"
		done

		# TODO: unbundle qt5
		# TODO: unbundle boost
		# TODO: unbundle icu
		# TODO: unbundle mesa
		# TODO: unbundle libSshClient
		# TODO: unbundle sqlite

		libs=( # {{{

			# media-libs/libglvnd
			libGL.so
			libGL.so.1
			libGL.so.1.5.0

			# dev-db/sqlite
			libsqlite3.so.0

			# dev-lang/python
			# sqlite3
			_sqlite3.cpython-310-x86_64-linux-gnu.so

			# dev-libs/elfutils
			libelf.so
			libelf.so.0.187
			libelf.so.1

			# dev-libs/opencl-icd-loader
			libOpenCL.so
			libOpenCL.so.1
			libOpenCL.so.1.0
			libOpenCL.so.1.0.0
		) # }}}

		for lib in "${libs[@]}"; do
			find "${ED}/${cudadir}" -name "${lib}" -delete
		done
	fi

	# remove rdma libs (unless USE=rdma)
	if ! use rdma; then
		rm "${ED}/${cudadir}/targets/${narch}-linux/lib/libcufile_rdma"* || die
	fi

	# rm "${ED}${cudadir}/bin/"*"-uninstaller"

	# Add include and lib symlinks
	dosym "targets/${narch}-linux/include" "${cudadir}/include"
	dosym "targets/${narch}-linux/lib" "${cudadir}/lib64"

	find "${ED}/${cudadir}" -empty -delete || die

	local revord=$(( 999999 - $(printf "%02d%02d%02d" "$(ver_cut 1)" "$(ver_cut 2)" "$(ver_cut 3)") ))

	use debugger && ldpathextradirs+=":${ecudadir}/extras/Debugger/lib64"
	use profiler && ldpathextradirs+=":${ecudadir}/extras/CUPTI/lib64"
	use vis-profiler && pathextradirs+=":${ecudadir}/libnvvp"

	newenvd - "99cuda${revord}" <<-EOF
		PATH=${ecudadir}/bin${pathextradirs}
		PKG_CONFIG_PATH=${ecudadir}/pkgconfig
		LDPATH=${ecudadir}/lib64:${ecudadir}/nvvm/lib64${ldpathextradirs}
	EOF

	# Cuda prepackages libraries, don't revdep-build on them
	insinto /etc/revdep-rebuild
	newins - "80${PN}${revord}" <<-EOF
		SEARCH_DIRS_MASK="${ecudadir}"
	EOF
}

pkg_postinst_check() {
	local a b v
	a="$("${EROOT}"/opt/cuda-${PV}/bin/cuda-config -s)"
	b="0.0"
	for v in ${a}; do
		ver_test "${v}" -gt "${b}" && b="${v}"
	done

	# if gcc and if not gcc-version is at least greatest supported
	if tc-is-gcc && \
		ver_test "$(gcc-version)" -gt "${b}"; then
			ewarn
			ewarn "gcc > ${b} will not work with CUDA"
			ewarn "Make sure you set an earlier version of gcc with gcc-config"
			ewarn "or append --compiler-bindir= pointing to a gcc bindir like"
			ewarn "--compiler-bindir=${EPREFIX}/usr/*pc-linux-gnu/gcc-bin/gcc${b}"
			ewarn "to the nvcc compiler flags"
			ewarn
	fi
}

pkg_postinst() {
	# if [[ ${MERGE_TYPE} != binary ]]; then
	# 	pkg_postinst_check
	# fi

	if use profiler || use nsight; then
		einfo
		einfo "nvidia-drivers restrict access to performance counters."
		einfo "You'll need to either run profiling tools (nvprof, nsight) "
		einfo "using sudo (needs cap SYS_ADMIN) or add the following line to "
		einfo "a modprobe configuration file "
		einfo "(e.g. /etc/modprobe.d/nvidia-prof.conf): "
		einfo
		einfo "options nvidia NVreg_RestrictProfilingToAdminUsers=0"
		einfo
	fi
}
