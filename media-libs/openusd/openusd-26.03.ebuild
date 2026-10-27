# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit cmake desktop python-single-r1 flag-o-matic toolchain-funcs xdg

DESCRIPTION="Universal Scene Description"
HOMEPAGE="http://www.openusd.org"

if [[ "${PV}" == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/PixarAnimationStudios/OpenUSD.git"
else
	SRC_URI="
		https://github.com/PixarAnimationStudios/OpenUSD/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	"
	S="${WORKDIR}/OpenUSD-${PV}"
	KEYWORDS="~amd64"
fi

LICENSE="
	Apache-2.0
	BSD
	BSD-2
	JSON
	MIT
"
# custom - https://github.com/PixarAnimationStudios/OpenUSD/blob/v24.05/pxr/usdImaging/usdImaging/drawModeStandin.cpp#L9
# custom - search "In consideration of your agreement"
SLOT="0"
# test USE flag is enabled upstream
IUSE="
	alembic debug doc draco embree examples hdf5 +imaging jemalloc man
	materialx monolithic color-management opengl openimageio openvdb openexr osl
	ptex +python +safety-over-speed static-libs tutorials test tools usdview vulkan
"

REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	alembic? (
		openexr
	)
	embree? (
		imaging
	)
	hdf5? (
		alembic
	)
	color-management? (
		imaging
	)
	imaging? (
		opengl
	)
	openimageio? (
		imaging
	)
	openvdb? (
		${OPENVDB_REQUIRED_USE}
		imaging
		openexr
	)
	osl? (
		openexr
	)
	ptex? (
		imaging
	)
	test? (
		python
	)
	usdview? (
		opengl
		python
	)
"

RDEPEND="
	!python? (
		>=dev-libs/boost-1.76.0:=
	)
	alembic? (
		>=media-gfx/alembic-1.8.5:=[hdf5?]
	)
	draco? (
		>=media-libs/draco-1.4.3:=
	)
	embree? (
		>=media-libs/embree-4.2.0:=
	)
	>=dev-cpp/tbb-2021.9:=
	hdf5? (
		>=sci-libs/hdf5-1.10[cxx,hl]
	)
	imaging? (
		>=media-libs/opensubdiv-3.6.0:=
		x11-libs/libX11
	)
	jemalloc? (
		dev-libs/jemalloc-usd
	)
	materialx? (
		>=media-libs/materialx-1.38.8:=[X,renderer]
	)
	color-management? (
		>=media-libs/opencolorio-2.1.3:=
	)
	openexr? (
		>=media-libs/openexr-3.1.5-r1:=
	)
	opengl? (
		>=media-libs/glew-2.0.0:=
		virtual/opengl[X]
	)
	openimageio? (
		media-libs/libjpeg-turbo:=
		>=media-libs/libpng-1.6.29
		>=media-libs/openimageio-2.3.21.0:=
		>=media-libs/tiff-4.0.7
	)
	openvdb? (
		>=dev-libs/c-blosc-1.17:=
		>=media-gfx/openvdb-9.1.0:=[blosc]
	)
	osl? (
		>=media-libs/osl-1.10.9:=
	)
	ptex? (
		>=media-libs/ptex-2.4.2:=
	)
	python? (
		${PYTHON_DEPS}
		$(python_gen_cond_dep '
			>=dev-libs/boost-1.76.0:=[python,${PYTHON_USEDEP}]
			opengl? (
				dev-python/pyopengl[${PYTHON_USEDEP}]
			)
			usdview? (
				(
					>=dev-python/pyside-6.2.0[${PYTHON_USEDEP},quick(+),tools(+),opengl?]
				)
			)
		')
	)
	vulkan? (
		>=dev-util/vulkan-headers-1.3.296.0
		>=media-libs/vulkan-layers-1.3.296.0
		>=dev-libs/vulkan-memory-allocator-3.0.0
		>=dev-libs/spirv-reflect-1.3.296.0
		>=dev-util/spirv-headers-1.3.296.0
		>=dev-util/glslang-1.3.296.0
	)
"
DEPEND="
	${RDEPEND}
"
BDEPEND="
	$(python_gen_cond_dep '
		>=dev-python/jinja2-2[${PYTHON_USEDEP}]
	')
	app-alternatives/yacc
	app-alternatives/lex
	dev-cpp/argparse
	dev-util/patchelf
	man? ( sys-apps/help2man )
	doc? (
		>=app-text/doxygen-1.9.6
		media-gfx/graphviz
	)
"

RESTRICT="!test? ( test )"

PATCHES=(
	"${FILESDIR}/algorithm.patch"
	"${FILESDIR}/packageUtils.cpp.patch"
	"${FILESDIR}/openusd-23.11-defaultfonts.patch"
	"${FILESDIR}/openusd-24.08-PVS-bugfix-base-trace-2313.patch"
	"${FILESDIR}/openusd-24.08-PVS-bugfix-envvar-2157.patch"
	"${FILESDIR}/openusd-24.08-PVS-bugfix-base-tf-2161.patch"
	"${FILESDIR}/openusd-25.05-cmake-FindBoost-fix.patch"
	"${FILESDIR}/${PN}-26.03-pxr-workTBB-Ensure-TBB_INTERFACE_VERSION_MAJOR-is-de.patch"
)

DOCS=( "CHANGELOG.md" "README.md" )

pkg_setup() {
	if use vulkan ; then
		if [[ -z "${VULKAN_SDK}" ]] ; then
			ewarn
			ewarn "VULKAN_SDK should be set as a per-package environmental variable"
			ewarn
			export VULKAN_SDK="${EPREFIX}/usr/include/vulkan"
		fi
	fi

	if use python; then
		python-single-r1_pkg_setup
	fi
}

src_prepare() {
	cmake_src_prepare

	# Fix python dirs
	if use python ; then
		eapply "${FILESDIR}/${PN}-23.11-fix-python.patch"
		sed \
			-e "s/\(set(INSTALL_PYTHON_PXR_ROOT \"\).*$/\1usr\/$(get_libdir)\/openusd\/lib\/python\/pxr\"\)/" \
			-e "s/\(--pythonPath \)\${CMAKE_INSTALL_PREFIX}\/lib\/python/\1usr\/$(get_libdir)\/openusd\/lib\/python/" \
			-i cmake/macros/Public.cmake || die
	fi

	if ! use opengl ; then
		# Disable X11
		sed -e '/find_package(X11)/d' \
			-e '/find_package(X11 REQUIRED)/d' \
			-e '/add_definitions(-DPXR_X11_SUPPORT_ENABLED)/d' \
			-i cmake/defaults/Packages.cmake || die
	fi

	rm -r docs/doxygen/doxygen-awesome-css || die

	if use elibc_musl; then
		eapply "${FILESDIR}"/openusd-25.08-fix-musl-build.patch
	fi
}

src_configure() {
	CMAKE_BUILD_TYPE=$(usex debug 'RelWithDebInfo' 'Release')

	filter-lto

	append-cppflags $(usex debug '-DDEBUG' '-DNDEBUG')
	append-cppflags -DTBB_ALLOCATOR_TRAITS_BROKEN

	if tc-is-clang; then
		append-cppflags --no-system-header-prefix pxr
	fi

	local -x USD_PATH="/usr/$(get_libdir)/${PN}"

	if use elibc_musl; then
		append-flags -D_LARGEFILE64_SOURCE
	fi

	if use draco; then
		append-cppflags \
			-DDRACO_ATTRIBUTE_INDICES_DEDUPLICATION_SUPPORTED=ON \
			-DDRACO_ATTRIBUTE_VALUES_DEDUPLICATION_SUPPORTED=ON \
			-DTBB_SUPPRESS_DEPRECATED_MESSAGES=1
	fi

	# See https://github.com/PixarAnimationStudios/OpenUSD/blob/v24.05/cmake/defaults/Options.cmake
	local mycmakeargs=(
		$(usex jemalloc "-DPXR_MALLOC_LIBRARY=${ESYSROOT}${USD_PATH}/$(get_libdir)/libjemalloc.so" "")
		# $(usex usdview "-DPYSIDEUICBINARY:PATH=${S}/pyside-uic" "")
		-DBUILD_SHARED_LIBS=ON
		-DCMAKE_CXX_STANDARD=17

		# -DCMAKE_POLICY_DEFAULT_CMP0072="OLD"
		-DCMAKE_POLICY_DEFAULT_CMP0167="OLD"
		-DCMAKE_POLICY_DEFAULT_CMP0177="OLD"
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}${USD_PATH}"
		-DPXR_VALIDATE_GENERATED_CODE=OFF
		-DPXR_STRICT_BUILD_MODE=OFF
		-DPXR_BUILD_ALEMBIC_PLUGIN=$(usex alembic)
		-DPXR_BUILD_DOCUMENTATION=$(usex doc)
		-DPXR_BUILD_PYTHON_DOCUMENTATION=$(usex doc $(usex python))
		-DPXR_BUILD_HTML_DOCUMENTATION=$(usex doc)
		-DPXR_BUILD_DRACO_PLUGIN=$(usex draco)
		-DPXR_BUILD_EMBREE_PLUGIN=$(usex embree)
		-DPXR_BUILD_EXAMPLES=$(usex examples)
		-DPXR_BUILD_IMAGING=$(usex imaging)
		# -DPXR_BUILD_METAL_PLUGIN=OFF
		-DPXR_BUILD_MONOLITHIC=$(usex monolithic)
		-DPXR_BUILD_OPENCOLORIO_PLUGIN=$(usex color-management)
		-DPXR_BUILD_OPENIMAGEIO_PLUGIN=$(usex openimageio)
		-DPXR_BUILD_PRMAN_PLUGIN=OFF
		-DPXR_BUILD_TESTS=$(usex test)
		-DPXR_HEADLESS_TEST_MODE=ON
		-DPXR_BUILD_TUTORIALS=$(usex tutorials)
		-DPXR_BUILD_USD_IMAGING=$(usex imaging)
		-DPXR_BUILD_USD_TOOLS=$(usex tools)
		-DPXR_BUILD_USDVIEW=$(usex usdview)
		-DPXR_ENABLE_GL_SUPPORT=$(usex opengl)
		-DPXR_ENABLE_HDF5_SUPPORT=$(usex hdf5)
		-DPXR_ENABLE_MATERIALX_SUPPORT=$(usex materialx)
		-DPXR_ENABLE_METAL_SUPPORT=OFF
		-DPXR_ENABLE_OPENVDB_SUPPORT=$(usex openvdb)
		-DPXR_ENABLE_OSL_SUPPORT=$(usex osl)
		-DPXR_ENABLE_PTEX_SUPPORT=$(usex ptex)
		-DPXR_ENABLE_PYTHON_SUPPORT=$(usex python)
		-DPXR_ENABLE_VULKAN_SUPPORT=$(usex vulkan)
		-DPXR_INSTALL_LOCATION="${EPREFIX}${USD_PATH}"

		-DPXR_PREFER_SAFETY_OVER_SPEED=$(usex safety-over-speed)
		-DPXR_PYTHON_SHEBANG="${PYTHON}"
		# -DPXR_USE_PYTHON_3=ON
		-DPXR_SET_INTERNAL_NAMESPACE="pxrBlender_v0_$(ver_cut 2)_$(ver_cut 3)"
		# -DCMAKE_FIND_DEBUG_MODE=yes
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	local -x USD_PATH="/usr/$(get_libdir)/${PN}"

	if use usdview; then
		dosym "${USD_PATH}/bin/usdview" /usr/bin/usdview
	fi

	dosym "${USD_PATH}"/include/pxr /usr/include/pxr
	echo "${USD_PATH}"/lib >> 99-${PN}.conf || die

	insinto /etc/ld.so.conf.d/
	doins 99-${PN}.conf

	local f
	for f in $(find "${ED}${USD_PATH}/lib" -name "*.so*") ; do
		einfo "Removing rpath from ${f}"
		patchelf --remove-rpath "${f}" || die # triggers warning
	done

	local -x STRIP="${BROOT}/bin/true" # strip breaks rpath

	if use jemalloc ; then
		for f in $(find "${ED}${USD_PATH}" -executable) ; do
			if ldd "${f}" 2>/dev/null | grep -q -e "libjemalloc.so.2" ; then
				einfo "Changing rpath for ${f} to use jemalloc-usd"
				local old_rpath=$(patchelf --print-rpath "${f}")
				if [[ -n "${old_rpath}" ]] ; then
					old_rpath=":${old_rpath}"
				fi
				patchelf --set-rpath "${EPREFIX}${USD_PATH}/$(get_libdir)${old_rpath}" "${f}" || die
			fi
		done

		if [[ -d "${ED}${USD_PATH}/bin" ]] ; then
			mv "${ED}${USD_PATH}/"{bin,.bin} || die
		fi

		local UTILS_LIST=(
			sdffilter
			testusdview
			usdGenSchema
			usdcat
			usdchecker
			usdcompress
			usddiff
			usddumpcrate
			usdedit
			usdrecord
			usdresolve
			usdstitch
			usdstitchclips
			usdtree
			usdview
			usdzip
		)

		# Setting LD_PRELOAD for jemalloc is still required or you may get a segfault
		exeinto ${USD_PATH}/bin
		local u
		for u in "${UTILS_LIST[@]}" ; do
			if [[ -e "${ED}${USD_PATH}/.bin/${u}" ]] ; then
				# TODO newexe
				einfo "Creating wrapper for ${u}"
				# echo -e "#!/bin/bash\nLD_PRELOAD=\"${EPREFIX}${USD_PATH}/$(get_libdir)/libjemalloc.so\"" "${EPREFIX}${USD_PATH}/.bin/${u}" "\$@" > "${T}/${u}"

				newexe - "${u}" <<- _EOF_
					#!${EPREFIX}/usr/bin/env bash
					LD_PRELOAD="${EPREFIX}${USD_PATH}/$(get_libdir)/libjemalloc.so" \
					"${EPREFIX}${USD_PATH}/.bin/${u}" "\${@}"
				_EOF_

				if use man; then
					help2man --no-info --no-discard-stderr --version-string="${PV}" \
						--output="${ED}/usr/share/man/man1/${u}.1" "${T}/${u}" || die
				fi
			fi
		done
	fi

	if use python ; then
		mkdir -p "${D}$(python_get_sitedir)" || die
		cp -rp \
			"${ED}${USD_PATH}/lib/python/pxr" \
			"${D}$(python_get_sitedir)/" || die
		rm -r \
			"${ED}${USD_PATH}/lib/python/pxr" || die

		# Remove stray python files generated by the build system
		find "${ED}" \( -name '*.pyc' -o -name '*.pyo' \) -exec rm -vf {} \; || die

		python_optimize
	fi

	if use usdview; then
		domenu "${FILESDIR}/org.openusd.usdview.desktop"
		newicon -s scalable "${FILESDIR}/openusd.svg" "openusd.svg"
	fi

	dodoc LICENSE.txt NOTICE.txt
}
