# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit check-reqs toolchain-funcs unpacker

DRIVER_PV="550.54.15"

DESCRIPTION="NVIDIA CUDA Toolkit (compiler and friends)"
HOMEPAGE="https://developer.nvidia.com/cuda-zone"
SRC_URI="https://developer.download.nvidia.com/compute/cuda/${PV}/local_installers/cuda_${PV}_${DRIVER_PV}_linux.run"
S="${WORKDIR}"

LICENSE="NVIDIA-CUDA"
SLOT="${PV}"
KEYWORDS="-* ~amd64 ~amd64-linux"
IUSE="debugger examples nsight profiler rdma vis-profiler sanitizer"
RESTRICT="bindist mirror"

# since CUDA 11, the bundled toolkit driver (== ${DRIVER_PV}) and the
# actual required minimum driver version are different.
RDEPEND="
	<sys-devel/gcc-14_pre[cxx]
	examples? (
		media-libs/freeglut
		media-libs/glu
	)
	nsight? (
		dev-libs/libpfm
		dev-libs/wayland
		dev-qt/qtwayland:6
		|| (
			dev-libs/openssl-compat:1.1.1
			dev-libs/openssl:0/1.1
		)
		media-libs/tiff-compat:4
		sys-libs/zlib
	)
	rdma? ( sys-cluster/rdma-core )
	vis-profiler? (
		>=virtual/jre-1.8:*
	)"
BDEPEND="nsight? ( dev-util/patchelf )"

QA_PREBUILT="opt/cuda/*"
CHECKREQS_DISK_BUILD="15000M"

pkg_setup() {
	check-reqs_pkg_setup
}

src_prepare() {
	# ATTENTION: change requires revbump, see link below for supported GCC # versions
	# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#system-requirements
	local cuda_supported_gcc="8.5 9.5 10 11 12 13"

	sed \
		-e "s:CUDA_SUPPORTED_GCC:${cuda_supported_gcc}:g" \
		"${FILESDIR}"/cuda-config.in > "${T}"/cuda-config || die

	default
}

src_install() {
	local cudadir=/opt/cuda-${PV}
	local ecudadir="${EPREFIX}${cudadir}"
	local pathextradirs ldpathextradirs
	dodir "${cudadir}"
	into "${cudadir}"
	insinto "${cudadir}"

	dofile() {
		echo "dofile $1"
		einfo doins -r "${@}"
		for x in "${@}"; do
			einfo chmod -R --reference="${x}" "${ED}${cudadir}/${x}"
		done
	}

	COMPONENTS=(
		Toolkit
		Libraries
		Development
		cuda-cccl
		cuda-cudart-dev
		cuda-driver-dev
		#cuda-nvml-dev
		#cuda-nvrtc-dev

		# cuda-opencl-dev
		# cuda-profiler-api
		# libcublas-dev
		# libcufft-dev
		# libcufile-dev
		# libcurand-dev
		# libcusolver-dev
		# libcusparse-dev
		# libnpp-dev
		# libnvfatbin-dev
		# libnvjitlink-dev
		# libnvjpeg-dev
		# Runtime
		# cuda-cudart
		# cuda-nvrtc
		# cuda-opencl
		# libcublas12
		# libcufft
		# libcufile
		# libcurand
		# libcusolver
		# libcusparse
		# libnpp
		# libnvfatbin
		# libnvjitlink
		# libnvjpeg
		# Tools
		# Command_Line_Tools
		# cuda-cupti
		# cuda-gdb
		# cuda-gdb-src
		# nvdisasm
		# nvprof
		# nvtx
		# compute-sanitizer
		# compute-sanitizer-integration
		# Visual_Tools
		# nsight
		# nvvp
		# nsight-compute
		# cuda-nsight-compute-integration
		# nsight-systems
		# cuda-nsight-systems-integration
		# Compiler
		# cuda-cuobjdump
		# cuda-cuxxfilt
		# cuda-nvcc
		# cuda-nvvm
		# cuda-crt
		# cuda-nvprune
		# Demo_Suite
		# Documentation
		# Driver
		# 550.54.15
		# Kernel_Objects
		# nvidia-fs
	)

	# CUDA Toolkit 12.4
	if has Toolkit "${COMPONENTS[@]}"; then
		# type: "toolkit"
		# priority: "9"
		# installPath: "/usr/local/cuda-12.4"

		cd "${S}/./builds/" || die

		einfo dodir "${cudadir}/"bin
		dofile version.json

		# CUDA Libraries 12.4
		if has Libraries "${COMPONENTS[@]}"; then
			# type: "libraries"



			# CUDA Development 12.4
			if has Development "${COMPONENTS[@]}"; then



				# cuda-cccl
				if has cuda-cccl "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_cccl/" || die

					einfo dodir "${cudadir}/"targets
					einfo dodir "${cudadir}/"targets/x86_64-linux
					einfo dodir "${cudadir}/"targets/x86_64-linux/include
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/include/*
					dofile include
					dofile targets/x86_64-linux/lib/*
					dofile lib64

				fi
				# cuda-cudart-dev
				if has cuda-cudart-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_cudart/" || die

					einfo dodir "${cudadir}/"targets
					einfo dodir "${cudadir}/"targets/x86_64-linux
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib
					einfo dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/*.so
					dofile targets/x86_64-linux/lib/*.a
					dofile targets/x86_64-linux/include/*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					einfo doins cudart-12.4.pc
					insinto "${cudadir}"

				fi
				# cuda-driver-dev
				if has cuda-driver-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_cudart/" || die

					einfo dodir "${cudadir}/"targets
					einfo dodir "${cudadir}/"targets/x86_64-linux
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dofile targets/x86_64-linux/lib/stubs/libcuda.so
					dofile lib64
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cuda-12.4.pc
					insinto "${cudadir}"

				fi
				# cuda-nvml-dev
				if has cuda-nvml-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvml_dev/" || die

					einfo dodir "${cudadir}/"nvml
					einfo dodir "${cudadir}/"targets
					einfo dodir "${cudadir}/"targets/x86_64-linux
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					einfo dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/stubs/libnvidia-ml.a
					dofile targets/x86_64-linux/lib/stubs/libnvidia-ml.so
					dofile targets/x86_64-linux/include/nvml.h
					dofile nvml
					dofile lib64
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvidia-ml-12.4.pc
					insinto "${cudadir}"

				fi
				# cuda-nvrtc-dev
				if has cuda-nvrtc-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvrtc/" || die

					einfo dodir "${cudadir}/"targets
					einfo dodir "${cudadir}/"targets/x86_64-linux
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib
					einfo dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					einfo dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/*.so
					dofile targets/x86_64-linux/lib/*.a
					dofile targets/x86_64-linux/lib/stubs/*
					dofile targets/x86_64-linux/include/*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvrtc-12.4.pc
					insinto "${cudadir}"

				fi
				# cuda-opencl-dev
				if has cuda-opencl-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_opencl/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/include
					dodir "${cudadir}/"targets/x86_64-linux/include/CL
					dofile targets/x86_64-linux/lib/*.so
					dofile targets/x86_64-linux/include/CL/*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins opencl-12.4.pc
					insinto "${cudadir}"

				fi
				# cuda-profiler-api
				if has cuda-profiler-api "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_profiler_api/" || die

					dodir "${cudadir}/"bin
					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/include/cuda_profiler_api.h
					dofile targets/x86_64-linux/include/cudaProfiler.h

				fi
				# libcublas-dev
				if has libcublas-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcublas/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dodir "${cudadir}/"src
					dofile targets/x86_64-linux/lib/libcublas.so
					dofile targets/x86_64-linux/lib/libcublas_static.a
					dofile targets/x86_64-linux/lib/libcublasLt.so
					dofile targets/x86_64-linux/lib/libcublasLt_static.a
					dofile targets/x86_64-linux/lib/libnvblas.so
					dofile targets/x86_64-linux/lib/stubs/libcublas.so
					dofile targets/x86_64-linux/lib/stubs/libcublasLt.so
					dofile targets/x86_64-linux/include/nvblas.h
					dofile targets/x86_64-linux/include/cublas_api.h
					dofile targets/x86_64-linux/include/cublas.h
					dofile targets/x86_64-linux/include/cublas_v2.h
					dofile targets/x86_64-linux/include/cublasLt.h
					dofile targets/x86_64-linux/include/cublasXt.h
					dofile src/fortran_thunking.c
					dofile src/fortran_common.h
					dofile src/fortran.h
					dofile src/fortran_thunking.h
					dofile src/fortran.c
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cublas-12.pc
					insinto "${cudadir}"

				fi
				# libcufft-dev
				if has libcufft-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcufft/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libcufft*.so
					dofile targets/x86_64-linux/lib/stubs/libcufft*.so*
					dofile targets/x86_64-linux/lib/libcufft*_static.a
					dofile targets/x86_64-linux/lib/libcufft_static_nocallback.a
					dofile targets/x86_64-linux/include/cufft*
					dofile targets/x86_64-linux/include/cudalibxt.h
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cufft-11.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cufftw-11.2.pc
					insinto "${cudadir}"

				fi
				# libcufile-dev
				if has libcufile-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcufile/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/include
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"gds
					dodir "${cudadir}/"gds-12.4
					dodir "${cudadir}/"gds/tools
					dodir "${cudadir}/"gds/doc
					dodir "${cudadir}/"gds/man
					dodir "${cudadir}/"gds/man/man3
					dofile targets/x86_64-linux/include/cufile.h
					dofile targets/x86_64-linux/lib/libcufile.so
					dofile targets/x86_64-linux/lib/libcufile_rdma.so
					dofile targets/x86_64-linux/lib/libcufile_static.a
					dofile targets/x86_64-linux/lib/libcufile_rdma_static.a
					dofile lib64
					dofile gds/cufile.json
					dofile gds/EULA.txt
					dofile gds/doc/*
					dofile gds/man/man3/*
					dofile gds/tools/*
					dofile gds-12.4/*
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cufile-1.9.pc
					insinto "${cudadir}"

				fi
				# libcurand-dev
				if has libcurand-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcurand/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libcurand.so
					dofile targets/x86_64-linux/lib/stubs/libcurand.so*
					dofile targets/x86_64-linux/lib/libcurand_static.a
					dofile targets/x86_64-linux/include/curand*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins curand-10.3.pc
					insinto "${cudadir}"

				fi
				# libcusolver-dev
				if has libcusolver-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcusolver/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libcusolver.so
					dofile targets/x86_64-linux/lib/libcusolverMg.so
					dofile targets/x86_64-linux/lib/stubs/libcusolver*
					dofile targets/x86_64-linux/lib/stubs/libcusolverMg*
					dofile targets/x86_64-linux/lib/libcusolver*_static.a
					dofile targets/x86_64-linux/lib/libmetis_static.a
					dofile targets/x86_64-linux/include/cusolver*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cusolver-11.6.pc
					insinto "${cudadir}"

				fi
				# libcusparse-dev
				if has libcusparse-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcusparse/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dodir "${cudadir}/"src
					dofile targets/x86_64-linux/lib/libcusparse.so*
					dofile targets/x86_64-linux/lib/stubs/libcusparse.so*
					dofile targets/x86_64-linux/lib/libcusparse_static.a
					dofile targets/x86_64-linux/include/cusparse*
					dofile src/cusparse_fortran*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cusparse-12.3.pc
					insinto "${cudadir}"

				fi
				# libnpp-dev
				if has libnpp-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnpp/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libnpp*.so
					dofile targets/x86_64-linux/lib/stubs/libnpp*.so*
					dofile targets/x86_64-linux/lib/libnpp*_static.a
					dofile targets/x86_64-linux/include/npp*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins npps-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppi-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppial-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppicc-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppicom-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppidei-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppif-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppig-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppim-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppist-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppisu-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppitc-12.2.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nppc-12.2.pc
					insinto "${cudadir}"

				fi
				# libnvfatbin-dev
				if has libnvfatbin-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvfatbin/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libnvfatbin.so
					dofile targets/x86_64-linux/lib/libnvfatbin_static.a
					dofile targets/x86_64-linux/lib/stubs/libnvfatbin.so
					dofile targets/x86_64-linux/include/nvFatbin*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvfatbin-12.4.pc
					insinto "${cudadir}"

				fi
				# libnvjitlink-dev
				if has libnvjitlink-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvjitlink/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/*.so
					dofile targets/x86_64-linux/lib/*.a
					dofile targets/x86_64-linux/lib/stubs/*
					dofile targets/x86_64-linux/include/*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvjitlink-12.4.pc
					insinto "${cudadir}"

				fi
				# libnvjpeg-dev
				if has libnvjpeg-dev "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvjpeg/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/libnvjpeg.so
					dofile targets/x86_64-linux/lib/stubs/libnvjpeg.so*
					dofile targets/x86_64-linux/lib/libnvjpeg_static.a
					dofile targets/x86_64-linux/include/nvjpeg*
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvjpeg-12.3.pc
					insinto "${cudadir}"

				fi
			fi
			# CUDA Runtime 12.4
			if has Runtime "${COMPONENTS[@]}"; then



				# cuda-cudart
				if has cuda-cudart "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_cudart/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/*.so.*
					dofile lib64

				fi
				# cuda-nvrtc
				if has cuda-nvrtc "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvrtc/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/*.so.*
					dofile lib64

				fi
				# cuda-opencl
				if has cuda-opencl "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_opencl/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/*.so.*
					dofile lib64

				fi
				# libcublas12
				if has libcublas12 "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcublas/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libcublas.so.*
					dofile targets/x86_64-linux/lib/libcublasLt.so.*
					dofile targets/x86_64-linux/lib/libnvblas.so.*
					dofile lib64

				fi
				# libcufft
				if has libcufft "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcufft/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libcufft*.so.*
					dofile lib64

				fi
				# libcufile
				if has libcufile "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcufile/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/include
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/include/cufile.h
					dofile targets/x86_64-linux/lib/libcufile.so.*
					dofile targets/x86_64-linux/lib/libcufile_rdma.so.*
					dofile lib64

				fi
				# libcurand
				if has libcurand "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcurand/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libcurand.so.*
					dofile lib64

				fi
				# libcusolver
				if has libcusolver "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcusolver/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libcusolver.so.*
					dofile targets/x86_64-linux/lib/libcusolverMg.so.*
					dofile lib64

				fi
				# libcusparse
				if has libcusparse "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libcusparse/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libcusparse.so.*
					dofile lib64

				fi
				# libnpp
				if has libnpp "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnpp/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libnpp*.so.*
					dofile lib64

				fi
				# libnvfatbin
				if has libnvfatbin "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvfatbin/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/lib/stubs
					dofile targets/x86_64-linux/lib/libnvfatbin.so.*
					dofile lib64

				fi
				# libnvjitlink
				if has libnvjitlink "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvjitlink/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/*.so.*
					dofile lib64

				fi
				# libnvjpeg
				if has libnvjpeg "${COMPONENTS[@]}"; then

					cd "${S}/./builds/libnvjpeg/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile targets/x86_64-linux/lib/libnvjpeg.so.*
					dofile lib64

				fi
			fi
		fi
		# CUDA Tools 12.4
		if has Tools "${COMPONENTS[@]}"; then
			# type: "tools"



			# CUDA Command Line Tools 12.4
			if has Command_Line_Tools "${COMPONENTS[@]}"; then



				# cuda-cupti
				if has cuda-cupti "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_cupti/" || die

					dodir "${cudadir}/"extras
					dodir "${cudadir}/"extras/CUPTI
					dofile extras/CUPTI

				fi
				# cuda-gdb
				if has cuda-gdb "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_gdb/" || die

					dodir "${cudadir}/"bin
					dodir "${cudadir}/"extras
					dodir "${cudadir}/"extras/Debugger
					dodir "${cudadir}/"share
					dofile bin/cuda-gdb
					dofile bin/cuda-gdbserver
					dofile extras/Debugger
					dofile share

				fi
				# cuda-gdb-src
				if has cuda-gdb-src "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_gdb/" || die

					dodir "${cudadir}/"extras
					dofile extras/cuda-gdb*.src.tar.gz

				fi
				# nvdisasm
				if has nvdisasm "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvdisasm/" || die

					dodir "${cudadir}/"bin
					dofile bin/nvdisasm

				fi
				# nvprof
				if has nvprof "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvprof/" || die

					dodir "${cudadir}/"bin
					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dofile bin/nvprof
					dofile targets/x86_64-linux/lib/libcuinj*
					dofile targets/x86_64-linux/lib/libaccinj*
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins cuinj64-12.4.pc
					insinto "${cudadir}"
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins accinj64-12.4.pc
					insinto "${cudadir}"

				fi
				# nvtx
				if has nvtx "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvtx/" || die

					dodir "${cudadir}/"targets
					dodir "${cudadir}/"targets/x86_64-linux
					dodir "${cudadir}/"targets/x86_64-linux/lib
					dodir "${cudadir}/"targets/x86_64-linux/include
					dofile targets/x86_64-linux/lib/*
					dofile targets/x86_64-linux/include/*
					dofile lib64
					dofile include
					insinto "/usr/$(get_libdir)/pkgconfig"
					doins nvToolsExt-12.4.pc
					insinto "${cudadir}"

				fi
				# compute-sanitizer
				if has compute-sanitizer "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_sanitizer_api/" || die

					dodir "${cudadir}/"compute-sanitizer
					dofile compute-sanitizer

					# compute-sanitizer-integration
					if has compute-sanitizer-integration "${COMPONENTS[@]}"; then

						cd "${S}/./builds/integration/Sanitizer/" || die

						dodir "${cudadir}/"bin
						dofile *

					fi
				fi
			fi
			# CUDA Visual Tools 12.4
			if has Visual_Tools "${COMPONENTS[@]}"; then



				# nsight
				if has nsight "${COMPONENTS[@]}"; then
					# priority: "9"

					cd "${S}/./builds/cuda_nsight/" || die

					dodir "${cudadir}/"bin
					dodir "${cudadir}/"nsightee_plugins
					dofile bin/nsight_ee_plugins_manage.sh
					dofile nsightee_plugins
					cat > "nsight.desktop" <<-EOF || die
						[Desktop Entry]
						Name=Nsight Eclipse Edition
						Categories=Development;IDE;Debugger;ParallelComputing
						Keywords=cuda;gpu;nvidia;debugger;
						Icon=libnsight/icon.xpm
						Exec=bin/nsight
						TryExec=bin/nsight
					EOF

				fi
				# nvvp
				if has nvvp "${COMPONENTS[@]}"; then

					cd "${S}/./builds/cuda_nvvp/" || die

					dodir "${cudadir}/"bin
					dodir "${cudadir}/"libnvvp
					dofile libnvvp
					dofile bin/computeprof
					dofile bin/nvvp
					cat > "nvvp.desktop" <<-EOF || die
						[Desktop Entry]
						Name=NVIDIA Visual Profiler
						Categories=Development;Profiling;ParallelComputing
						Keywords=nvvp;cuda;gpu;nsight;
						Icon=libnvvp/icon.xpm
						Exec=bin/nvvp
						TryExec=bin/nvvp
					EOF

				fi
				# nsight-compute
				if has nsight-compute "${COMPONENTS[@]}"; then
					# priority: "8"

					cd "${S}/./builds/nsight_compute/" || die

					dodir "${cudadir}/"nsight-compute-2024.1.1
					dofile *
					cat > "nsight-compute.desktop" <<-EOF || die
						[Desktop Entry]
						Name=Nsight Compute
						Categories=Development;Profiling;ParallelComputing
						Keywords=cuda;gpu;nvidia;nsight;
						Icon=nsight-compute-2024.1.1/host/linux-desktop-glibc_2_11_3-x64/ncu-ui.png
						Exec=nsight-compute-2024.1.1/host/linux-desktop-glibc_2_11_3-x64/ncu-ui
						TryExec=nsight-compute-2024.1.1/host/linux-desktop-glibc_2_11_3-x64/ncu-ui
					EOF

					# cuda-nsight-compute-integration
					if has cuda-nsight-compute-integration "${COMPONENTS[@]}"; then

						cd "${S}/./builds/integration/nsight-compute/" || die

						dodir "${cudadir}/"bin
						dofile *

					fi
				fi
				# nsight-systems
				if has nsight-systems "${COMPONENTS[@]}"; then
					# priority: "7"

					cd "${S}/./builds/nsight_systems/" || die

					dodir "${cudadir}/"nsight-systems-2023.4.4
					dodir "${cudadir}/"targets
					dodir "${cudadir}/"nsight-systems-2023.4.4/bin
					dodir "${cudadir}/"nsight-systems-2023.4.4/documentation
					dodir "${cudadir}/"nsight-systems-2023.4.4/target-linux-x64
					dodir "${cudadir}/"nsight-systems-2023.4.4/host-linux-x64
					dodir "${cudadir}/"nsight-systems-2023.4.4/host-linux-x64/Scripts
					dofile *
					cat > "nsight-systems.desktop" <<-EOF || die
						[Desktop Entry]
						Name=Nsight Systems
						Categories=Development;Profiling;ParallelComputing
						Keywords=cuda;gpu;nvidia;nsight;
						Icon=nsight-systems-2023.4.4/host-linux-x64/nsight-sys.png
						Exec=nsight-systems-2023.4.4/host-linux-x64/nsight-sys
						TryExec=nsight-systems-2023.4.4/host-linux-x64/nsight-sys
					EOF

					# cuda-nsight-systems-integration
					if has cuda-nsight-systems-integration "${COMPONENTS[@]}"; then

						cd "${S}/./builds/integration/nsight-systems/" || die

						dodir "${cudadir}/"bin
						dofile *

					fi
				fi
			fi
		fi
		# CUDA Compiler 12.4
		if has Compiler "${COMPONENTS[@]}"; then
			# type: "compiler"



			# cuda-cuobjdump
			if has cuda-cuobjdump "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_cuobjdump/" || die

				dodir "${cudadir}/"bin
				dofile bin/cuobjdump

			fi
			# cuda-cuxxfilt
			if has cuda-cuxxfilt "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_cuxxfilt/" || die

				dodir "${cudadir}/"bin
				dodir "${cudadir}/"targets
				dodir "${cudadir}/"targets/x86_64-linux
				dodir "${cudadir}/"targets/x86_64-linux/lib
				dodir "${cudadir}/"targets/x86_64-linux/include
				dofile bin/cu++filt
				dofile targets/x86_64-linux/lib/*
				dofile targets/x86_64-linux/include/*
				dofile include
				dofile lib64

			fi
			# cuda-nvcc
			if has cuda-nvcc "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_nvcc/" || die

				dodir "${cudadir}/"targets
				dodir "${cudadir}/"targets/x86_64-linux
				dodir "${cudadir}/"targets/x86_64-linux/include
				dodir "${cudadir}/"targets/x86_64-linux/lib
				dodir "${cudadir}/"bin
				dofile targets/x86_64-linux/include/*.h
				dofile targets/x86_64-linux/lib/*
				dofile bin/*
				dofile include
				dofile lib64

			fi
			# cuda-nvvm
			if has cuda-nvvm "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_nvcc/" || die

				dodir "${cudadir}/"nvvm
				dofile nvvm*

			fi
			# cuda-crt
			if has cuda-crt "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_nvcc/" || die

				dodir "${cudadir}/"targets
				dodir "${cudadir}/"targets/x86_64-linux
				dodir "${cudadir}/"targets/x86_64-linux/include
				dodir "${cudadir}/"targets/x86_64-linux/include/crt
				dofile bin/crt
				dofile targets/x86_64-linux/include/crt

			fi
			# cuda-nvprune
			if has cuda-nvprune "${COMPONENTS[@]}"; then

				cd "${S}/./builds/cuda_nvprune/" || die

				dodir "${cudadir}/"bin
				dofile bin/nvprune

			fi
		fi
	fi
	# CUDA Demo Suite 12.4
	if has Demo_Suite "${COMPONENTS[@]}"; then
		# type: "doc"
		# priority: "1"
		# installPath: "/usr/local/cuda-12.4/"

		cd "${S}/./builds/cuda_demo_suite/" || die

		dodir "${cudadir}/"extras
		dodir "${cudadir}/"extras/demo_suite
		dodir "${cudadir}/"bin
		dofile bin/cuda-uninstaller
		dofile extras/demo_suite

	fi
	# CUDA Documentation 12.4
	if has Documentation "${COMPONENTS[@]}"; then
		# type: "doc"
		# installPath: "/usr/local/cuda-12.4/"

		cd "${S}/./builds/cuda_documentation/" || die

		dodir "${cudadir}/"tools
		dodir "${cudadir}/"bin
		dofile bin/cuda-uninstaller
		dofile tools
		dofile EULA.txt
		dofile DOCS
		dofile README

	fi
	# Driver
	if has Driver "${COMPONENTS[@]}"; then
		# type: "driver"
		# priority: "10"
		# single-selection: "None"

		cd "${S}/./builds/" || die


		# 550.54.15
		if has 550.54.15 "${COMPONENTS[@]}"; then
			# single-selection: "None"


			dofile NVIDIA-Linux-x86_64-550.54.15.run

		fi
	fi
	# Kernel Objects
	if has Kernel_Objects "${COMPONENTS[@]}"; then
		# type: "kernelobjects"
		# installPath: "/usr/local/kernelobjects"

		cd "${S}/./builds/" || die

		dodir "${cudadir}/"bin
		dofile bin/ko-uninstaller

		# nvidia-fs
		if has nvidia-fs "${COMPONENTS[@]}"; then
			# type: "kernelobjects"
			# koversion: "2.19.7"
			# installPath: "/usr/src/nvidia-fs-2.19.7"

			cd "${S}/./builds/nvidia_fs/usr/src/" || die

			dofile *

		fi
	fi
	set +x
	# # Install standard sub packages
	# local builddirs=(
	# 	builds/cuda_{cccl,cudart,cuobjdump,cuxxfilt,demo_suite,nvcc,nvdisasm,nvml_dev,nvprune,nvrtc,nvtx,opencl}
	# 	builds/lib{cublas,cufft,cufile,curand,cusolver,cusparse,npp,nvjitlink,nvjpeg}
	# 	builds/nvidia_fs
	# 	$(usex profiler "builds/cuda_nvprof builds/cuda_cupti builds/cuda_profiler_api" "")
	# 	$(usex vis-profiler "builds/cuda_nvvp" "")
	# 	$(usex debugger "builds/cuda_gdb" "")
	# )
  #
	# local d f
	# for d in "${builddirs[@]}"; do
	# 	ebegin "Installing ${d}"
	# 	[[ -d ${d} ]] || die "Directory does not exist: ${d}"
  #
	# 	if [[ -d ${d}/bin ]]; then
	# 		for f in ${d}/bin/*; do
	# 			if [[ -f ${f} ]]; then
	# 				dobin "${f}"
	# 			else
	# 				insinto "${cudadir}"/bin
	# 				doins -r "${f}"
	# 			fi
	# 		done
	# 	fi
  #
	# 	insinto "${cudadir}"
	# 	if [[ -d ${d}/targets ]]; then
	# 		doins -r "${d}"/targets
	# 	fi
	# 	if [[ -d ${d}/share ]]; then
	# 		doins -r "${d}"/share
	# 	fi
	# 	if [[ -d ${d}/extras ]]; then
	# 		doins -r "${d}"/extras
	# 	fi
	# 	eend $?
	# done
	# dobin "${T}"/cuda-config
  #
	# doins builds/EULA.txt
	# # nvml and nvvm need special handling
	# ebegin "Installing nvvm"
	# doins -r builds/cuda_nvcc/nvvm
	# fperms +x ${cudadir}/nvvm/bin/cicc
	# eend $?
  #
	# ebegin "Installing nvml"
	# doins -r builds/cuda_nvml_dev/nvml
	# eend $?
  #
	# if use sanitizer; then
	# 	ebegin "Installing sanitizer"
	# 	dobin builds/integration/Sanitizer/compute-sanitizer
	# 	doins -r builds/cuda_sanitizer_api/compute-sanitizer
	# 	# special handling for the executable
	# 	fperms +x ${cudadir}/compute-sanitizer/compute-sanitizer
	# 	eend $?
	# fi
  #
	# use debugger && ldpathextradirs+=":${ecudadir}/extras/Debugger/lib64"
	# use profiler && ldpathextradirs+=":${ecudadir}/extras/CUPTI/lib64"
  #
	# if use vis-profiler; then
	# 	ebegin "Installing libnvvp"
	# 	doins -r builds/cuda_nvvp/libnvvp
	# 	# special handling for the executable
	# 	fperms +x ${cudadir}/libnvvp/nvvp
	# 	eend $?
	# 	pathextradirs+=":${ecudadir}/libnvvp"
	# fi
  #
	# if use nsight; then
	# 	local ncu_dir=$(grep -o 'nsight-compute-[0-9][0-9\.]*' -m1 manifests/cuda_x86_64.xml)
	# 	ebegin "Installing ${ncu_dir}"
	# 	mv builds/nsight_compute builds/${ncu_dir} || die
	# 	doins -r builds/${ncu_dir}
  #
	# 	# check this list on every bump
	# 	local exes=(
	# 		${ncu_dir}/ncu
	# 		${ncu_dir}/ncu-ui
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/libexec/QtWebEngineProcess
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/CrashReporter
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/OpenGLVersionChecker
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/QdstrmImporter
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/ncu-ui
	# 		${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/ncu-ui.bin
	# 		${ncu_dir}/target/linux-desktop-glibc_2_11_3-x64/TreeLauncherSubreaper
	# 		${ncu_dir}/target/linux-desktop-glibc_2_11_3-x64/TreeLauncherTargetLdPreloadHelper
	# 		${ncu_dir}/target/linux-desktop-glibc_2_11_3-x64/ncu
	# 	)
  #
	# 	dobin builds/integration/nsight-compute/{ncu,ncu-ui}
	# 	eend $?
  #
	# 	# remove rdma libs (unless USE=rdma)
	# 	if ! use rdma; then
	# 		rm -r "${ED}"/${cudadir}/${ncu_dir}/host/target-linux-x64/CollectX || die
	# 	fi
  #
	# 	local nsys_dir=$(grep -o 'nsight-systems-[0-9][0-9\.]*' -m1 manifests/cuda_x86_64.xml)
	# 	ebegin "Installing ${nsys_dir}"
	# 	mv builds/nsight_systems builds/${nsys_dir} || die
	# 	doins -r builds/${nsys_dir}
  #
	# 	# check this list on every bump
	# 	exes+=(
	# 		${nsys_dir}/host-linux-x64/nsys-ui
	# 		${nsys_dir}/host-linux-x64/nsys-ui.bin
	# 		${nsys_dir}/host-linux-x64/ResolveSymbols
	# 		${nsys_dir}/host-linux-x64/ImportNvtxt
	# 		${nsys_dir}/host-linux-x64/CrashReporter
	# 		${nsys_dir}/host-linux-x64/QdstrmImporter
	# 		${nsys_dir}/host-linux-x64/libexec/QtWebEngineProcess
	# 		${nsys_dir}/target-linux-x64/nsys
	# 		${nsys_dir}/target-linux-x64/launcher
	# 		${nsys_dir}/target-linux-x64/nvgpucs
	# 		${nsys_dir}/target-linux-x64/nsys-launcher
	# 		${nsys_dir}/target-linux-x64/sqlite3
	# 		${nsys_dir}/target-linux-x64/python/bin/python
	# 		${nsys_dir}/target-linux-x64/CudaGpuInfoDumper
	# 	)
  #
	# 	# remove rdma libs (unless USE=rdma)
	# 	if ! use rdma; then
	# 		rm -r "${ED}"/${cudadir}/${nsys_dir}/target-linux-x64/CollectX || die
	# 	fi
  #
	# 	dobin builds/integration/nsight-systems/{nsight-sys,nsys,nsys-ui}
	# 	eend $?
  #
	# 	# nsight scripts and binaries need to have their executable bit set, #691284
	# 	for f in "${exes[@]}"; do
	# 		fperms +x ${cudadir}/${f}
	# 	done
  #
	# 	# fix broken RPATHs
	# 	patchelf --set-rpath '$ORIGIN' \
	# 	"${ED}"/${cudadir}/${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/{libarrow.so,libparquet.so.500.0.0} || die
	# 	patchelf --set-rpath '$ORIGIN' \
	# 	"${ED}"/${cudadir}/${nsys_dir}/host-linux-x64/{libarrow.so,libparquet.so.500.0.0} || die
  #
	# 	# remove foreign archs (triggers SONAME warning, #749903)
	# 	rm -r "${ED}"/${cudadir}/${ncu_dir}/target/linux-desktop-glibc_2_19_0-ppc64le || die
	# 	rm -r "${ED}"/${cudadir}/${ncu_dir}/target/linux-desktop-t210-a64 || die
  #
	# 	# unbundle libstdc++
	# 	rm "${ED}"/${cudadir}/${nsys_dir}/host-linux-x64/libstdc++.so.6 || die
  #
	# 	# unbundle openssl
	# 	rm "${ED}"/${cudadir}/${ncu_dir}/host/linux-desktop-glibc_2_11_3-x64/lib{crypto,ssl}.so* || die
	# 	rm "${ED}"/${cudadir}/${nsys_dir}/host-linux-x64/lib{crypto,ssl}.so* || die
  #
	# 	# unbundle libpfm
	# 	rm "${ED}"/${cudadir}/${nsys_dir}/host-linux-x64/libpfm.so* || die
  #
	# 	# TODO: unbundle qt5
	# 	# TODO: unbundle boost
	# 	# TODO: unbundle icu
	# 	# TODO: unbundle mesa
	# 	# TODO: unbundle libSshClient
	# 	# TODO: unbundle sqlite
	# fi
  #
	# if use examples; then
	# 	local exes=(
	# 		extras/demo_suite/bandwidthTest
	# 		extras/demo_suite/busGrind
	# 		extras/demo_suite/deviceQuery
	# 		extras/demo_suite/nbody
	# 		extras/demo_suite/oceanFFT
	# 		extras/demo_suite/randomFog
	# 		extras/demo_suite/vectorAdd
	# 	)
  #
	# 	# set executable bit on demo_suite binaries
	# 	for f in "${exes[@]}"; do
	# 		fperms +x ${cudadir}/${f}
	# 	done
	# else
	# 	rm -r "${ED}"/${cudadir}/extras/demo_suite || die
	# fi
  #
	# # remove rdma libs (unless USE=rdma)
	# if ! use rdma; then
	# 	rm "${ED}"/${cudadir}/targets/x86_64-linux/lib/libcufile_rdma* || die
	# fi
  #
	# # Add include and lib symlinks
	# dosym targets/x86_64-linux/include ${cudadir}/include
	# dosym targets/x86_64-linux/lib ${cudadir}/lib64
  #
	# # Remove bad symlinks
	# rm "${ED}"/${cudadir}/targets/x86_64-linux/include/include || die
	# rm "${ED}"/${cudadir}/targets/x86_64-linux/lib/lib64 || die
  #
	# newenvd - 99cuda <<-EOF
	# 	PATH=${ecudadir}/bin${pathextradirs}
	# 	ROOTPATH=${ecudadir}/bin
	# 	LDPATH=${ecudadir}/lib64:${ecudadir}/nvvm/lib64${ldpathextradirs}
	# EOF
  #
	# # Cuda prepackages libraries, don't revdep-build on them
	# insinto /etc/revdep-rebuild
	# newins - 80${PN} <<-EOF
	# 	SEARCH_DIRS_MASK="${ecudadir}"
	# EOF
  #
	# # https://bugs.gentoo.org/926116
	# insinto /etc/sandbox.d
	# newins - 80${PN} <<-EOF
	# 	SANDBOX_PREDICT="/proc/self/task"
	# EOF
}

pkg_postinst_check() {
	local a="$("${EROOT}"/opt/cuda/bin/cuda-config -s)"
	local b="0.0"
	local v
	for v in ${a}; do
		ver_test "${v}" -gt "${b}" && b="${v}"
	done

	# if gcc and if not gcc-version is at least greatest supported
	if tc-is-gcc && \
		ver_test $(gcc-version) -gt "${b}"; then
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
	if [[ ${MERGE_TYPE} != binary ]]; then
		pkg_postinst_check
	fi

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
