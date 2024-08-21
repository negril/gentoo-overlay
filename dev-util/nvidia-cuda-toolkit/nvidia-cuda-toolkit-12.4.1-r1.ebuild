# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..12} )
inherit check-reqs desktop unpacker python-r1

DRIVER_PV="550.54.15"
# grep "unsupported (GNU|clang) version" builds/cuda_nvcc/targets/x86_64-linux/include/crt/host_config.h
GCC_MAX_VER="13"
CLANG_MAX_VER="17"

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
KEYWORDS="-* ~amd64 ~arm64 ~amd64-linux"
IUSE="debugger examples nsight profiler rdma vis-profiler sanitizer system-qt"
RESTRICT="bindist mirror strip test"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# ./cuda-installer --silent --toolkit --no-opengl-libs --no-drm
# since CUDA 11, the bundled toolkit driver (== ${DRIVER_PV}) and the
# actual required minimum driver version are different.
RDEPEND="${PYTHON_DEPS}
	|| (
		<sys-devel/gcc-$(( GCC_MAX_VER + 1 ))_pre[cxx]
		<sys-devel/clang-$(( CLANG_MAX_VER + 1 ))_pre
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
		dev-libs/libpfm
		dev-qt/qtwayland:6=
		sys-cluster/ucx

		!system-qt? (
			dev-libs/nss
			virtual/krb5
			x11-libs/libXcomposite
			x11-libs/libXdamage
			x11-libs/libXtst
			x11-libs/libxkbfile
			x11-libs/libxshmfence
		)
		system-qt? (
			dev-qt/qtwebengine:6=[opengl]
			dev-qt/qtscxml:6=[qml]
			dev-qt/qtpositioning:6=
			dev-qt/qttools:6=
			dev-qt/qtcharts:6=
		)
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
	local -x SKIP_COMPONENTS=(
		"Kernel_Objects"
		"cuda-gdb-src"
	)

	! use debugger     && SKIP_COMPONENTS+=( "cuda-gdb" "cuda-gdb-src" )
	! use examples     && SKIP_COMPONENTS+=( "Demo_Suite" "Documentation" )
	! use nsight       && SKIP_COMPONENTS+=( "nsight" "nsight-compute" "nsight-systems" )
	! use profiler     && SKIP_COMPONENTS+=( "cuda-cupti" "cuda-profiler-api" "nvprof" )
	! use sanitizer    && SKIP_COMPONENTS+=( "compute-sanitizer" )
	! use vis-profiler && SKIP_COMPONENTS+=( "nvvp" )

	local ldpathextradirs pathextradirs
	local cudadir="/opt/cuda-${PV}"
	local ecudadir="${EPREFIX}${cudadir}"
	dodir "${cudadir}"
	into "${cudadir}"

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

	dofile() {
		local _DESTDIR="$(dirname "${1}")"
		if [[ "${_DESTDIR}" == '.' ]]; then
			_DESTDIR="${cudadir%/}/"
		else
			_DESTDIR="${cudadir%/}/${_DESTDIR%/}/"
		fi

		if [[ $# -gt 1  ]]; then
			_DESTDIR+="${2%/}/"
		fi

		insinto "${_DESTDIR}"

		for file in ${1}; do
			if [[ -f "${ED}${_DESTDIR}$(basename "${file}")" ]]; then
				continue
			fi
			ebegin "${_DESTDIR}$(basename "${file}") installing" # {{{

			local opts=
			[[ -d "${file}" ]] && opts="-r"

			doins ${opts} "${file}"
			eend $? #}}}

			readarray -t fs < <( find "${file}" -type f -executable )
			for f in "${fs[@]}"; do
				local _DESTFILE _SRCFILE
				_SRCFILE="$(pwd)/${f}"
				_DESTFILE="${_DESTDIR}$( realpath -s --relative-to="$(dirname "${1}")" "${f}" )"

				ebegin "${_DESTFILE} setting permissions" # {{{
				chmod -R --reference="${f}" "${ED}${_DESTFILE}" \
					|| die "failed to copy permissions from ${_SRCFILE} to ${ED}${_DESTFILE}"
				eend $? # }}}
			done
		done
	}

	dopcfile() {
		dodir "${ecudadir}/pkgconfig"
		cat > "${D}${ecudadir}/pkgconfig/${1}.pc" <<-EOF || die
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

	fix_executable=(
		cuda_cupti/extras/CUPTI/samples/pc_sampling_utility/pc_sampling_utility_helper.h
		cuda_cupti/extras/CUPTI/samples/pc_sampling_continuous/libpc_sampling_continuous.pl
		cuda_nvvp/libnvvp/icon.xpm
		cuda_opencl/targets/x86_64-linux/include/CL/cl.hpp
		libcufile/gds/tools/run_gdsio.cfg
		libcufile/targets/x86_64-linux/lib/libcufile_rdma_static.a
		libcufile/targets/x86_64-linux/lib/libcufile_static.a
	)
	chmod -x "${fix_executable[@]/#/builds/}" || die

	ebegin "parsing manifest" "${S}/manifests/cuda_"*.xml # {{{
	${EPYTHON} "${FILESDIR}/parse_manifest.py" "${S}/manifests/cuda_"*.xml &> "${T}/install.sh"
	eval "$(${EPYTHON} "${FILESDIR}/parse_manifest.py" "${S}/manifests/cuda_"*.xml )"
	eend $? # }}}

	if use debugger; then
		# rm "${ED}/${cudadir}/extras/cuda-gdb-"*".src.tar.gz" || die # 12.5.39
		# if [[ -d "${ED}/${cudadir}/extras/Debugger/lib64" ]]; then
		# 	rmdir "${ED}/${cudadir}/extras/Debugger/lib64" || die
		# fi

		rm "${ED}/${cudadir}/bin/cuda-gdb-"*"-tui" || die
		install_cuda-gdb-tui() {
			dobin "builds/cuda_gdb/bin/cuda-gdb-${EPYTHON}-tui"
		}

		cd "${S}" || die
		into "${cudadir}"
		python_foreach_impl install_cuda-gdb-tui

		for tui in builds/cuda_gdb/bin/cuda-gdb-*-tui; do
			tui_name=$(basename "${tui}")
		  if [[ ! -f "${ED}/${cudadir}/bin/${tui_name}" ]]; then
				sed -e "/${tui_name}\"/d" -i "${ED}/${cudadir}/bin/cuda-gdb" || die
			fi
		done
	fi

	if use nsight; then
		local ncu_dir nsys_dir
		ncu_dir=$( ls -d "${ED}${cudadir}/nsight-compute-"* || die )
		nsys_dir=$( ls -d "${ED}${cudadir}/nsight-systems-"* || die )

		sed \
			-e "s#${nsys_dir_host}/nsight-sys#${nsys_dir_host}/nsys-ui#g" \
			-i "${ED}/usr/share/applications/nsight-systems-"*.desktop \
			|| die

		readarray -t rpath_libs < <(find "${ED}${cudadir}/"nsight* -name libparquet.so.500.0.0 -o -name libarrow.so.500.0.0 )
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

		if use system-qt; then
			libs+=(
				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/Plugins/wayland-"*
				"${nsys_dir}/host-linux-${nsys_dir_host}/Plugins/wayland-"*

				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libexec/QtWebEngineProcess"
				"${nsys_dir}/host-linux-${nsys_dir_host}/libexec/QtWebEngineProcess"

				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/libexec/qt.conf"
				"${nsys_dir}/host-linux-${nsys_dir_host}/libexec/qt.conf"

				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/resources/"{icu,qtwebengine_}*
				"${nsys_dir}/host-linux-${nsys_dir_host}/resources/"{icu,qtwebengine_}*

				"${ncu_dir}/host/linux-desktop-${ncu_dir_host}/translations/qtwebengine_locales"
				"${nsys_dir}/host-linux-${nsys_dir_host}/translations/qtwebengine_locales"
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
		) # }}}
		if use system-qt; then
			libs+=( # {{{
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
		fi

		libs+=( # {{{
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
	fi

	# remove rdma libs (unless USE=rdma)
	if ! use rdma; then
		rm "${ED}/${cudadir}/targets/${narch}-linux/lib/libcufile_rdma"* || die
	fi

	# rm ${ED}${cudadir}/bin/*-uninstaller

	# Add include and lib symlinks
	dosym "targets/${narch}-linux/include" "${cudadir}/include"
	dosym "targets/${narch}-linux/lib" "${cudadir}/lib64"

	find "${ED}/${cudadir}" -empty -delete || die

	local revord=$(( 999999 - $(printf "%02d%02d%02d" $(echo "${PV}" | tr '.' ' ')) ))

	use debugger && ldpathextradirs+=":${ecudadir}/extras/Debugger/lib64"
	use profiler && ldpathextradirs+=":${ecudadir}/extras/CUPTI/lib64"
	use vis-profiler && pathextradirs+=":${ecudadir}/libnvvp"

	newenvd - "99cuda${revord}" <<-EOF
		PKG_CONFIG_PATH=${ecudadir}/pkgconfig
		LDPATH=${ecudadir}/lib64:${ecudadir}/nvvm/lib64${ldpathextradirs}
	EOF

	# Cuda prepackages libraries, don't revdep-build on them
	insinto /etc/revdep-rebuild
	newins - "80${PN}${revord}" <<-EOF
		SEARCH_DIRS_MASK="${ecudadir}"
	EOF
}

# pkg_postinst_check() {
# 	local a b v
# 	a="$("${EROOT}"/opt/cuda/bin/cuda-config -s)"
# 	b="0.0"
# 	for v in ${a}; do
# 		ver_test "${v}" -gt "${b}" && b="${v}"
# 	done
#
# 	# if gcc and if not gcc-version is at least greatest supported
# 	if tc-is-gcc && \
# 		ver_test "$(gcc-version)" -gt "${b}"; then
# 			ewarn
# 			ewarn "gcc > ${b} will not work with CUDA"
# 			ewarn "Make sure you set an earlier version of gcc with gcc-config"
# 			ewarn "or append --compiler-bindir= pointing to a gcc bindir like"
# 			ewarn "--compiler-bindir=${EPREFIX}/usr/*pc-linux-gnu/gcc-bin/gcc${b}"
# 			ewarn "to the nvcc compiler flags"
# 			ewarn
# 	fi
# }
#
# pkg_postinst() {
# 	if [[ ${MERGE_TYPE} != binary ]]; then
# 		pkg_postinst_check
# 	fi
#
# 	if use profiler || use nsight; then
# 		einfo
# 		einfo "nvidia-drivers restrict access to performance counters."
# 		einfo "You'll need to either run profiling tools (nvprof, nsight) "
# 		einfo "using sudo (needs cap SYS_ADMIN) or add the following line to "
# 		einfo "a modprobe configuration file "
# 		einfo "(e.g. /etc/modprobe.d/nvidia-prof.conf): "
# 		einfo
# 		einfo "options nvidia NVreg_RestrictProfilingToAdminUsers=0"
# 		einfo
# 	fi
# }
