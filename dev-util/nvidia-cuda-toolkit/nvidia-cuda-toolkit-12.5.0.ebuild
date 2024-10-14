# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
inherit check-reqs unpacker python-r1

DRIVER_PV="555.42.02"

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
SLOT="0/${PV}"
KEYWORDS="-* ~amd64 ~amd64-linux"
IUSE="debugger examples nsight profiler rdma vis-profiler sanitizer +system-qt"
RESTRICT="bindist mirror"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# ./cuda-installer --silent --toolkit --no-opengl-libs --no-drm
# since CUDA 11, the bundled toolkit driver (== ${DRIVER_PV}) and the
# actual required minimum driver version are different.
RDEPEND="${PYTHON_DEPS}
	<sys-devel/gcc-14_pre[cxx]
	examples? (
		media-libs/freeglut
		media-libs/glu
	)
	nsight? (
		app-crypt/mit-krb5
		dev-libs/libpfm
		dev-libs/openssl-compat:1.1.1
		media-libs/tiff-compat:4
		sys-cluster/ucx
		sys-libs/zlib
		>=x11-drivers/nvidia-drivers-${DRIVER_PV}[X]
		system-qt? (
			dev-qt/qtbase[network,widgets]
			dev-qt/qtwayland:6=
			dev-qt/qtwebengine:6=
			dev-qt/qtpositioning:6=
			dev-qt/qtscxml:6=
			dev-qt/qttools:6=
			dev-qt/qtcharts:6=
		)
	)
	rdma? ( sys-cluster/rdma-core )
	vis-profiler? (
		virtual/jre:1.8
	)
"
# 	nsight? (
# 		dev-qt/qtwayland:6
BDEPEND="nsight? ( dev-util/patchelf )"

QA_PREBUILT="opt/cuda-${PV}/*"
CHECKREQS_DISK_BUILD="15M"

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

	# safe some space, we don't need the driver here
	rm builds/NVIDIA-Linux-*-${DRIVER_PV}.run || die
}

src_install() {
	# eval "$(echo "olddie()"; declare -f die | tail -n +2)"

	# die() {
	# 	PORTAGE_NONFATAL=1 olddie -n
	# }

	dofperms(){
		cmd="$1"
		shift
		for f in "$@"; do
			if [[ ! -f "${ED}/${f}" ]]; then
				echo "${ED}/${f} missing"
				find "${ED}" -name "$(basename "${f}")" -ls | sed -e 's/^/\t/g'
				echo
			else
				fperms "${cmd}" "$f"
			fi
		done
	}

	local cudadir=/opt/cuda
	local ecudadir="${EPREFIX}${cudadir}"
	local pathextradirs ldpathextradirs
	dodir ${cudadir}
	into ${cudadir}

	# Install standard sub packages
	local builddirs=(
		builds/cuda_{cccl,cudart,cuobjdump,cuxxfilt,nvcc,nvdisasm,nvml_dev,nvprune,nvrtc,nvtx}
		builds/lib{cublas,cufft,cufile,curand,cusolver,cusparse,npp,nvjitlink,nvjpeg}
		builds/nvidia_fs
	)

	use profiler && builddirs+=( builds/cuda_cupti builds/cuda_profiler_api )
	use debugger && builddirs+=( builds/cuda_gdb )

	if use amd64; then
		builddirs+=(
			builds/cuda_opencl
		)
		use examples && builddirs+=( builds/cuda_demo_suite )
		use profiler && builddirs+=( builds/cuda_nvprof )
		use vis-profiler && builddirs+=( builds/cuda_nvvp )
	fi

	local ncu_dir_host ncu_dir_target nsys_dir_host nsys_dir_target

	if use amd64; then
		ncu_dir_host=glibc_2_11_3-x64
		ncu_dir_target=glibc_2_11_3-x64
		nsys_dir_host=x64
		nsys_dir_target=x64
		narch=x86_64
	elif use arm64; then
		ncu_dir_host=t210-a64
		ncu_dir_target=t210-a64
		nsys_dir_host=armv8
		nsys_dir_target=sbsa-armv8
		narch=sbsa
	fi

	local d f
	for d in "${builddirs[@]}"; do
		ebegin "Installing ${d}"
		[[ -d ${d} ]] || die "Directory does not exist: ${d}"

		if [[ -d ${d}/bin ]]; then
			for f in "${d}/bin/"*; do
				if [[ -f ${f} ]]; then
					dobin "${f}"
				else
					insinto ${cudadir}/bin
					doins -r "${f}"
				fi
			done
		fi

		insinto ${cudadir}
		if [[ -d ${d}/targets ]]; then
			doins -r "${d}"/targets
		fi
		if [[ -d ${d}/share ]]; then
			doins -r "${d}"/share
		fi
		if [[ -d ${d}/extras ]]; then
			doins -r "${d}"/extras
		fi
		eend $?
	done
	dobin "${T}"/cuda-config

	doins builds/EULA.txt
	# nvml and nvvm need special handling
	ebegin "Installing nvvm"
	doins -r builds/cuda_nvcc/nvvm
	dofperms +x ${cudadir}/nvvm/bin/cicc
	eend $?

	ebegin "Installing nvml"
	doins -r builds/cuda_nvml_dev/nvml
	eend $?

	if use debugger; then
		rm "${ED}/${cudadir}/extras/cuda-gdb-"*".src.tar.gz" || die # 12.5.39
		# if [[ -d "${ED}/${cudadir}/extras/Debugger/lib64" ]]; then
		# 	rmdir "${ED}/${cudadir}/extras/Debugger/lib64" || die
		# fi

		rm "${ED}/${cudadir}/bin/cuda-gdb-"*"-tui" || die
		install_cuda-gdb-tui() {
			dobin "builds/cuda_gdb/bin/cuda-gdb-${EPYTHON}-tui"
		}

		python_foreach_impl install_cuda-gdb-tui

		for tui in builds/cuda_gdb/bin/cuda-gdb-*-tui; do
			tui_name=$(basename "${tui}")
		  if [[ ! -f "${ED}/${cudadir}/bin/${tui_name}" ]]; then
				sed -e "/${tui_name}\"/d" -i "${ED}/${cudadir}/bin/cuda-gdb" || die
			fi
		done
	fi

	if ! use examples; then
		rm "${ED}/${cudadir}/nvml/" -r || die
	fi

	if use sanitizer; then
		ebegin "Installing sanitizer"
		dobin builds/integration/Sanitizer/compute-sanitizer
		ebegin "Installing sanitizer"
		dobin builds/integration/Sanitizer/compute-sanitizer
		doins -r builds/cuda_sanitizer_api/compute-sanitizer

		# special handling for the executable
		dofperms +x ${cudadir}/compute-sanitizer/{compute-sanitizer,TreeLauncherSubreaper,TreeLauncherTargetLdPreloadHelper}
		eend $?

		rm "${ED}/${cudadir}/compute-sanitizer/x86" -r || die
	fi

	use debugger && ldpathextradirs+=":${ecudadir}/extras/Debugger/lib64"
	if use vis-profiler; then
		ebegin "Installing libnvvp"
		doins -r builds/cuda_nvvp/libnvvp
		# special handling for the executable
		dofperms +x ${cudadir}/libnvvp/nvvp
		eend $?
		pathextradirs+=":${ecudadir}/libnvvp"
	fi

	if use nsight; then
		local ncu_dir
		ncu_dir=$(grep -o 'nsight-compute-[0-9][0-9\.]*' -m1 manifests/cuda_*.xml)
		ebegin "Installing ${ncu_dir}"
		mv builds/nsight_compute "builds/${ncu_dir}" || die
		doins -r "builds/${ncu_dir}"

		# check this list on every bump
		local exes=(
			"${ncu_dir}/ncu"
			"${ncu_dir}/ncu-ui"
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/CrashReporter"
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/OpenGLVersionChecker"
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/ncu-ui"
			"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/ncu-ui.bin"
			"${ncu_dir}/host/target-linux-${nsys_dir_target}/CudaGpuInfoDumper"
			"${ncu_dir}/host/target-linux-${nsys_dir_target}/launcher"
			"${ncu_dir}/host/target-linux-${nsys_dir_target}/nsys"
			"${ncu_dir}/host/target-linux-${nsys_dir_target}/nsys-launcher"
			"${ncu_dir}/host/target-linux-${nsys_dir_target}/nvgpucs"

			"${ncu_dir}/target/linux-desktop-${ncu_dir_target}/TreeLauncherSubreaper"
			"${ncu_dir}/target/linux-desktop-${ncu_dir_target}/TreeLauncherTargetLdPreloadHelper"
			"${ncu_dir}/target/linux-desktop-${ncu_dir_target}/ncu"
		)
		if ! use system-qt; then
			exes+=(
				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libexec/QtWebEngineProcess"
			)
		fi
		if use amd64; then
			exes+=(
				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/QdstrmImporter"
			)
		fi

		dobin builds/integration/nsight-compute/{ncu,ncu-ui}
		eend $?

		# remove rdma libs (unless USE=rdma)
		if ! use rdma; then
			rm -r "${ED}/${cudadir}/${ncu_dir}/host/target-linux-${nsys_dir_host}/CollectX" || die
		fi

		local nsys_dir
		nsys_dir=$(grep -o 'nsight-systems-[0-9][0-9\.]*' -m1 manifests/cuda_*.xml)
		ebegin "Installing ${nsys_dir}"
		mv builds/nsight_systems "builds/${nsys_dir}" || die
		doins -r "builds/${nsys_dir}"

		# check this list on every bump
		exes+=(
			"${nsys_dir}/host-linux-${nsys_dir_host}/CrashReporter"
			"${nsys_dir}/host-linux-${nsys_dir_host}/QdstrmImporter"
			"${nsys_dir}/host-linux-${nsys_dir_host}/nsys-ui"
			"${nsys_dir}/host-linux-${nsys_dir_host}/nsys-ui.bin"
			"${nsys_dir}/target-linux-${nsys_dir_target}/CudaGpuInfoDumper"
			"${nsys_dir}/target-linux-${nsys_dir_target}/launcher"
			"${nsys_dir}/target-linux-${nsys_dir_target}/nsys"
			"${nsys_dir}/target-linux-${nsys_dir_target}/nsys-launcher"
			# "${nsys_dir}/target-linux-${nsys_dir_target}/python/bin/python"
			# "${nsys_dir}/target-linux-${nsys_dir_target}/sqlite3"
		)
		if ! use system-qt; then
			exes+=(
				"${nsys_dir}/host-linux-${nsys_dir_host}/libexec/QtWebEngineProcess"
			)
		fi
		if use amd64; then
			exes+=(
				"${nsys_dir}/host-linux-${nsys_dir_host}/ImportNvtxt"
				"${nsys_dir}/host-linux-${nsys_dir_host}/ResolveSymbols"
				"${nsys_dir}/target-linux-${nsys_dir_target}/nvgpucs"
			)
		fi

		# remove rdma libs (unless USE=rdma)
		if ! use rdma; then
			rm -r "${ED}/${cudadir}/${nsys_dir}/target-linux-${nsys_dir_host}/CollectX" || die
		fi

		dobin builds/integration/nsight-systems/{nsight-sys,nsys,nsys-ui}
		eend $?

		# nsight scripts and binaries need to have their executable bit set, #691284
		for f in "${exes[@]}"; do
			dofperms +x "${cudadir}/${f}"
			eend $?
		done

		# remove foreign archs (triggers SONAME warning, #749903)
		if ! use arm64; then
			rm "${ED}/${cudadir}/${ncu_dir}/target/linux-desktop-glibc_2_11_3-x86" -r || die
			rm "${ED}/${cudadir}/${ncu_dir}/target/linux-desktop-t210-a64" -r || die
		fi

		# unbundle libstdc++
		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libstdc++.so.6" || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/libstdc++.so.6" || die

		# unbundle openssl
		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/lib"{crypto,ssl}".so"* || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/lib"{crypto,ssl}".so"* || die

		# rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libssh.so"* || die
		# rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/libssh.so"* || die

		# unbundle libpfm
		if use amd64; then
			rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libpfm.so"* || die
			rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/libpfm.so"* || die
		fi

		if use system-qt; then
		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/Plugins/wayland-"* -r || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/Plugins/wayland-"* -r || die

		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libexec/QtWebEngineProcess" || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/libexec/QtWebEngineProcess" || die

		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libexec/qt.conf" || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/libexec/qt.conf" || die

		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/resources/"{icu,qtwebengine_}* || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/resources/"{icu,qtwebengine_}* || die

		rm "${ED}/${cudadir}/${ncu_dir}/host/linux-desktop-${ncu_dir_host}/translations/qtwebengine_locales" -r || die
		rm "${ED}/${cudadir}/${nsys_dir}/host-linux-${nsys_dir_host}/translations/qtwebengine_locales" -r || die
		fi

		rm "${ED}/${cudadir}/${ncu_dir}/"*/*"/python/bin/python" || die
		rm "${ED}/${cudadir}/${nsys_dir}/"*"/python/bin/python" || die

		rm "${ED}/${cudadir}/${ncu_dir}/"*/*"/sqlite3" || die
		rm "${ED}/${cudadir}/${nsys_dir}/"*"/sqlite3" || die



		# TODO: unbundle qt5
		# TODO: unbundle boost
		# TODO: unbundle icu
		# TODO: unbundle mesa
		# TODO: unbundle libSshClient
		# TODO: unbundle sqlite
	fi

	if use examples; then
		local exes=(
			extras/demo_suite/bandwidthTest
			extras/demo_suite/busGrind
			extras/demo_suite/deviceQuery
			extras/demo_suite/nbody
			extras/demo_suite/oceanFFT
			extras/demo_suite/randomFog
			extras/demo_suite/vectorAdd
		)

		# set executable bit on demo_suite binaries
		for f in "${exes[@]}"; do
			dofperms +x "${cudadir}/${f}"
			eend $?
		done
	fi

	# remove rdma libs (unless USE=rdma)
	if ! use rdma; then
		rm "${ED}/${cudadir}/targets/${narch}-linux/lib/libcufile_rdma"* || die
	fi

	libs=( # {{{
		# dev-libs/apache-arrow
		# libarrow.so
		# libarrow.so.500
		# libarrow.so.500.0.0
		# libparquet.so
		# libparquet.so.500
		# libparquet.so.500.0.0

		# # dev-libs/boost
		# libboost_atomic.so.1.78.0
		# libboost_chrono.so.1.78.0
		# libboost_container.so.1.78.0
		# libboost_date_time.so.1.78.0
		# libboost_filesystem.so.1.78.0
		# libboost_iostreams.so.1.78.0
		# libboost_python310.so.1.78.0
		# libboost_program_options.so.1.78.0
		# libboost_regex.so.1.78.0
		# libboost_serialization.so.1.78.0
		# libboost_system.so.1.78.0
		# libboost_thread.so.1.78.0
		# libboost_timer.so.1.78.0

		# media-libs/libglvnd
		libGL.so
		libGL.so.1
		libGL.so.1.5.0
	)
	use system-qt && \
	libs+=(
		# dev-qt/qtbase
		libQt6Concurrent.so.6
		libQt6Core.so.6
		libQt6DBus.so.6
		libQt6Gui.so.6
		libQt6Network.so.6
		libQt6OpenGL.so.6
		libQt6OpenGLWidgets.so.6
		libQt6PrintSupport.so.6
		libQt6Test.so.6
		libQt6Widgets.so.6
		libQt6XcbQpa.so.6
		libQt6Xml.so.6
		libqcertonlybackend.so
		libqgif.so
		libqico.so
		libqjpeg.so
		libqoffscreen.so
		libqopensslbackend.so
		libqxcb-glx-integration.so
		libqxcb.so

		# dev-qt/qtcharts
		libQt6Charts.so.6

		# dev-qt/qtdeclarative
		libQt6Qml.so.6
		libQt6QmlModels.so.6
		libQt6Quick.so.6
		libQt6QuickParticles.so.6
		libQt6QuickTest.so.6
		libQt6QuickWidgets.so.6

		# dev-qt/qtimageformats
		libqtga.so
		libqtiff.so
		libqwbmp.so

		# dev-qt/qtmultimedia
		libQt6Multimedia.so.6
		libQt6MultimediaQuick.so.6
		libQt6MultimediaWidgets.so.6

		# dev-qt/qtpositioning
		libQt6Positioning.so.6

		# dev-qt/qtscxml
		libQt6StateMachine.so.6

		# dev-qt/qtsvg
		libQt6Svg.so.6
		libQt6SvgWidgets.so.6
		libqsvg.so

		# dev-qt/qtsensors
		libQt6Sensors.so.6
		libQt6Sql.so.6

		# dev-qt/qttools
		libQt6Designer.so.6
		libQt6UiTools.so.6
		libQt6DesignerComponents.so.6
		libQt6Help.so.6

		# dev-qt/qtwayland
		libQt6WaylandClient.so.6
		libQt6WaylandCompositor.so.6
		libQt6WaylandEglClientHwIntegration.so.6
		libQt6WaylandEglCompositorHwIntegration.so.6
		libqt-plugin-wayland-egl.so
		libqwayland-egl.so
		libqwayland-generic.so
		libvulkan-server.so
		libwl-shell-plugin.so
		libxdg-shell.so

		# dev-qt/qtwebchannel
		libQt6WebChannel.so.6

		# dev-qt/qtwebengine
		libQt6WebEngineCore.so.6
		libQt6WebEngineWidgets.so.6

		# sys-libs/zlib
		libz.so
		libz.so.1
		libz.so.1.2.7

		# dev-libs/icu
		libicudata.so.71
		libicui18n.so.71
		libicuuc.so.71

		# media-libs/freetype
		libfreetype.so.6

		# media-libs/jpeg-compat
		libjpeg.so.8

		libzstd.so.1
		)
	libs+=(
		# dev-db/sqlite
		libsqlite3.so.0

		# sys-devel/gcc
		# libstdc++.so.6

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

		#
		# libssl.so.10
		# libcrypto.so.10
		#
	) # }}}

	for lib in "${libs[@]}"; do
		find "${ED}/${cudadir}" -name "${lib}" -delete
	done

	rm "${ED}/${cudadir}/bin/cuda-uninstaller" || die
	rm "${ED}/${cudadir}/bin/nsight-sys" || die
	dofperms -x "${cudadir}/bin/nvcc.profile" ; eend $?


	readarray -t libs_so < <(find "${ED}/${cudadir}" -name '*.so*' -type f )
	for lib in "${libs_so[@]}"; do
		echo "lib ${lib#"${ED}"}" || die
		chmod +x "${lib}" || die
	done

# 	readarray -t exes < <(find "${ED}/${cudadir}" -type f -executable  )
# 	for exe in "${exes[@]}"; do
# 		:
# 		# echo "exe ${exe}"
# 		patchelf --set-rpath '$ORIGIN' "${exe}" \
# 		# 	|| die
# 		# patchelf --remove-rpath "${exe}"|| die
# 	done

	# Add include and lib symlinks
	dosym "targets/${narch}-linux/include" ${cudadir}/include
	dosym "targets/${narch}-linux/lib" ${cudadir}/lib64

	# Remove bad symlinks
	rm "${ED}/${cudadir}/targets/${narch}-linux/include/include" || die
	rm "${ED}/${cudadir}/targets/${narch}-linux/lib/lib64" || die

	newenvd - 99cuda <<-EOF
		PATH=${ecudadir}/bin${pathextradirs}
		ROOTPATH=${ecudadir}/bin
		LDPATH=${ecudadir}/lib64:${ecudadir}/nvvm/lib64${ldpathextradirs}
	EOF

	# Cuda prepackages libraries, don't revdep-build on them
	insinto /etc/revdep-rebuild
	newins - "80${PN}" <<-EOF
		SEARCH_DIRS_MASK="${ecudadir}"
	EOF

	# https://bugs.gentoo.org/926116
	insinto /etc/sandbox.d
	newins - "80${PN}" <<-EOF
		SANDBOX_PREDICT="/proc/self/task"
	EOF

	# eval "$(echo "die()"; declare -f olddie | tail -n +2)"
	# die "end of ${EBUILD_PHASE}"
}

pkg_postinst_check() {
	local a b v
	a="$("${EROOT}"/opt/cuda/bin/cuda-config -s)"
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
