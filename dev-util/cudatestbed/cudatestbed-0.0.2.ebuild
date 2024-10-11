# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# inherit cmake cuda multiprocessing virtualx

inherit cuda multilib-minimal

DESCRIPTION="A cuda testbed"
HOMEPAGE="https://git.jötunheimr.org/negril/cudatestbed"
SRC_URI="
"
S="${WORKDIR}"

LICENSE="BSD LGPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~x86 ~amd64-linux ~x86-linux"

IUSE="+cuda test"

RESTRICT="!test? ( test )"

RDEPEND="
"
# 	foo/bar[${CUDA_USEDEP}]
DEPEND="
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
"

REQUIRED_USE="${CUDA_REQUIRED_USE}"

PATCHES=(
)

DOCS=(
)

debugp() {
	:
	einfo "$1 \"${!1}\""
}

debuge() {
	echo "${@}" >&2
}

vtk_check_compiler() {
	[[ -z "$1" ]] && die "no compiler specified"
	local compiler="$1"
	local package="sys-devel/${compiler}"
	local version="${package}"
	local CUDAHOSTCXX_test=
	while true; do
		version=$(best_version "${version}")
		if [[ -z "${version}" ]]; then
			die "could not find supported version of ${package}"
		fi
		CUDAHOSTCXX_test="$(
			dirname "$(
				realpath "$(
					which "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
				)"
			)"
		)"
		if nvcc "-ccbin=${CUDAHOSTCXX_test}" - -x cu <<<"int main(){}" &>/dev/null; then
			CUDAHOSTCXX="${CUDAHOSTCXX_test}"
			einfo "using =${version#"<"}"
			return
		fi
		version="<${version}"
	done
}

# cuda_get_host_compiler() {
# 	# einfo "running cuda_get_host_compiler"
#
# 	local compiler="$(tc-getCC)"
# 	local compiler_version="$($(tc-get-compiler-type)-major-version)"
# 	# debugp compiler_version
# 	compiler="${compiler/%-${compiler_version}}"
# 	# debugp compiler
#
# 	if ! tc-is-gcc && ! tc-is-clang; then
# 		die "${compiler} compiler is not supported"
# 	fi
#
# 	# local compiler_type="$(tc-get-compiler-type)"
# 	# debugp compiler_type
#
# 	# local default_compiler="${compiler_type}-$("${compiler_type}-major-version")"
# 	# debugp default_compiler
#
# 	if [[ "${compiler%%[[:space:]]*}" == "ccache" ]]; then
# 		compiler="${compiler/#ccache }"
# 		local PATH="/usr/lib/ccache/bin:${PATH}"
# 	fi
# 	# debugp compiler
#
# 	# store the package so we can re-use it later
# 	local package="sys-devel/$(tc-get-compiler-type)"
# 	# debugp package
#
# 	local version="${package}"
# 	# debugp version
# 	# debuge
#
# 	# return
# 	# try the default compiler first
# 	# einfo "trying the default compiler first: $default_compiler"
# 	# local NVCC_CCBIN="${default_compiler}"
# 	# # local NVCC_CCBIN="${default_compiler}-$("${compiler}-major-version")" # doesn't work g++-14-14: No such file or directory
# 	# debugp default_compiler
# 	local NVCC_CCBIN="$(command -v "${compiler}-${compiler_version}")"
# 	einfo "trying the default compiler first: ${NVCC_CCBIN}"
# 	# local compiler_launcher_path="$(dirname "${NVCC_CCBIN}")"
# 	# debugp compiler_launcher_path
#
# 	# debuge
# 	# einfo "using CUDA $(nvcc --version | tail -n 1 | cut -d '_' -f 2- | cut -d '.' -f 1-2)"
# 	# nvcc -ccbin "${NVCC_CCBIN}" - -x cu <<<"int main(){}"
# 	# debuge
# 	while ! nvcc -ccbin "${NVCC_CCBIN}" - -x cu <<<"int main(){}" &>/dev/null; do
# 		version="<$(best_version "${version}")"
# 		# debugp version
# 		# debugp compiler
# 		# einfo "${compiler}-$(echo "${version}" | grep -oP "(?<=${package}-)[0-9]*")"
# 		# einfo "${compiler}-${version//<${package}-/}"
#
# 		if [[ "${version}" == "<" ]]; then
# 			die "could not find a supported version of ${compiler}"
# 		fi
# 		# debugp version
# 		# debugp package
#
# 		# einfo "${compiler_launcher_path}/${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
#
# 		# nvcc accepts just an executable name, too.
# 		# search for NVCC_CCBIN here:
# 		# https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/
#
# 		# # NVCC_CCBIN="$(
# 		# 						 echo "${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# 			command -pv "${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# 		realpath "$(
# 		# 			command -pv "${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# 		)"
# 		# 	dirname "$(
# 		# 		realpath "$(
# 		# 			command -pv "${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# 		)"
# 		# 	)"
# 		# # )"
# 		# # debugp NVCC_CCBIN
# 		# NVCC_CCBIN="${compiler_type}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# einfo "${version//<${package}-/}"
# 		# einfo "$(ver_cut 1 "${version//<${package}-/}")"
#
# 		# einfo "${compiler}-$(ver_cut 1 "${version//<${package}-/}")"
# 		# einfo "$(command -v "${compiler}-$(ver_cut 1 "${version//<${package}-/}")")"
#
# 		NVCC_CCBIN="$(command -v "${compiler}-$(ver_cut 1 "${version//<${package}-/}")")"
# 		# debugp NVCC_CCBIN
# 		# NVCC_CCBIN="$(echo "${version}" | sed 's:.*/\([a-z]*-[0-9]*\).*:\1:')"
# 		# debuge "${version}" | sed 's:.*/\([a-z]*-[0-9]*\).*:\1:'
# 		# debuge
# 	done
#
# 	# if [[ ${NVCC_CCBIN} != ${compiler_type} ]]; then
# 	# 	ewarn "The default compiler, ${compiler_type} is not supported by nvcc!"
# 	# 	ewarn "Compiler version mismatch causes undefined reference errors on linking, so"
# 	# 	ewarn "${NVCC_CCBIN}, which is supported by nvcc, will be used to compile OpenCV."
# 	# fi
#
# 	echo "${NVCC_CCBIN}"
# 	# debugp NVCC_CCBIN
# }

cuda_get_host_compiler() {
	if [[ -n "${CUDAHOSTCXX}" ]]; then
		echo "${CUDAHOSTCXX}"
		return
	fi

	einfo "trying to find working CUDA host compiler"

	local compiler compiler_type compiler_version
	local package package_version
	local NVCC_CCBIN

	compiler_type="$(tc-get-compiler-type)"
	compiler_version="$("${compiler_type}-major-version")"

	compiler="$(tc-getCC)"
	compiler="${compiler/%-${compiler_version}}"

	# store the package so we can re-use it later
	package="sys-devel/${compiler_type}"
	package_version="${package}"

	if ! tc-is-gcc && ! tc-is-clang; then
		die "${compiler} compiler is not supported"
	fi

	if [[ "${compiler%%[[:space:]]*}" == "ccache" ]]; then
		compiler="${compiler/#ccache }"
		local PATH="/usr/lib/ccache/bin:${PATH}"
	fi

	# try the default compiler first
	NVCC_CCBIN="$(command -v "${compiler}-${compiler_version}")"
	ebegin "testing default compiler: ${compiler_type}-${compiler_version}"

	while ! nvcc -ccbin "${NVCC_CCBIN}" - -x cu <<<"int main(){}" &>/dev/null; do
		eend 1
		# prepare next version
		if ! package_version="<$(best_version "${package_version}")"; then
			die "could not find a supported version of ${compiler}"
		fi

		compiler_version="$(ver_cut 1 "${package_version/#<${package}-/}")"
		NVCC_CCBIN="$(command -v "${compiler}-${compiler_version}")"
		ebegin "testing ${compiler_type}-${compiler_version}"
	done
	eend $?

	echo "${NVCC_CCBIN}"
}

# pkg_setup() {
	# /opt/cuda-12.5.0/bin/__nvcc_device_query
# }

src_prepare() {
	eapply_user

	# mkdir -p "${S}"
	# cmake_src_prepare
}

multilib_src_configure() {
	# cuda_get_host_compiler
	# die done11
	NVCC_CCBIN="$(cuda_get_host_compiler)"
	debugp NVCC_CCBIN
	# nvcc -v -ccbin "${NVCC_CCBIN}" - -x cu <<<"int main(){}"
	die done
	if use cuda; then
		cuda_add_sandbox -w
		# if [[ ! -d /sys/module/nvidia ]]; then
		# 	einfo "loading nvidia module"
		# 	nvidia-modprobe || die
		# fi
		#
		# if [[ ! -d /sys/module/nvidia_uvm ]]; then
		# 	einfo "loading nvidia_uvm module"
		# 	nvidia-modprobe -u || die
		# fi
		#
		# local i WRITE
		#
		# # /dev/dri/card*
		# # /dev/dri/renderD*
		# readarray -t dri <<<"$(find /sys/module/nvidia/drivers/*/*:*:*.*/drm -mindepth 1 -maxdepth 1 -type d -exec basename {} \;| sed 's:^:/dev/dri/:')"
		#
		# # /dev/nvidia{0-9}
		# readarray -t cards <<<"$(find /dev -regextype sed -regex '/dev/nvidia[0-9]*')"
		#
		# WRITE+=(
		# 	"${dri[@]}"
		# 	"${cards[@]}"
		# 	/dev/nvidiactl
		# 	/dev/nvidia-uvm*
		#
		# 	# for portage
		# 	/proc/self/task/
		# )
		# for i in "${WRITE[@]}"; do
		# 	einfo "addwrite $i"
		# 	addwrite "$i"
		# done
		#
		# PREDICT=(
		# 	# /dev/char/
		# 	# /root
		# 	# /dev/crypto
		# 	# /var/cache/man
		# 	# /var/cache/fontconfig
		# 	# /proc/self/maps
		# 	# /dev/console
		# 	# /dev/random
		# 	# /proc/self/task/
		# )
		# for i in "${PREDICT[@]}"; do
		# 	echo "addpredict $i"
		# 	addpredict "$i"
		# done

		# /opt/cuda-12.5.0/bin/__nvcc_device_query failed to call cudaLoader::cuInit(0) with error 0x3e7 (CUDA_ERROR_UNKNOWN)

		# addpredict /proc/self/task
		# addwrite /proc/self/task
		# addpredict
		# SANDBOX_READ="/"
		# if tc-is-gcc; then
		# 	vtk_check_compiler "gcc"
		# 	CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE="$(LANG=C.UTF8 "${CUDAHOSTCXX}/gcc" -print-search-dirs | grep 'install:' | cut -d ' ' -f 2 | sed -e 's#/*$##g' - || die)"
		# 	export CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE
		# fi
		# tc-is-clang && vtk_check_compiler "clang"

		# 'echo "SANDBOX_READ ${SANDBOX_READ}"; echo "SANDBOX_WRITE ${SANDBOX_WRITE}";echo "SANDBOX_PREDICT ${SANDBOX_PREDICT}";/opt/cuda-12.5.0/bin/__nvcc_device_query'
		# sandbox bash -c 'echo "SANDBOX_READ ${SANDBOX_READ}"; echo "SANDBOX_WRITE ${SANDBOX_WRITE}";echo "SANDBOX_PREDICT ${SANDBOX_PREDICT}"'

		# echo
		# env | grep portage | sort
		# echo

		device_query() {
			/opt/cuda-12.5.1/bin/__nvcc_device_query

		}
		echo "SANDBOX_READ=${SANDBOX_READ}"
		echo "SANDBOX_WRITE=${SANDBOX_WRITE}"
		echo "SANDBOX_PREDICT=${SANDBOX_PREDICT}"
		echo "SANDBOX_DENY=${SANDBOX_DENY}"

		echo -n "cuda arch "
		sandbox \
			/opt/cuda-12.5.1/bin/__nvcc_device_query
		echo

		# command -v /opt/cuda-12.5.1/bin/__nvcc_device_query
		# echo

		echo -n "cuda arch "
		/opt/cuda-12.5.1/bin/__nvcc_device_query
		echo

	# 	ls -alh /dev/nvidia*
	# 	# strace -f -e file /opt/cuda-12.5.0/bin/__nvcc_device_query
	# 	# strace -f -e file nvidia-modprobe -u
	# 	# die
	# 	# [[ -z "${CUDAARCHS}" ]] && einfo "trying to determine host CUDAARCHS"
	# 	# : "${CUDAARCHS:=$(/opt/cuda-12.5.0/bin/__nvcc_device_query || die "could not query nvcc device")}"
	# 	# einfo "building for CUDAARCHS = ${CUDAARCHS}"
  #   #
	# 	# einfo "CUDAHOSTCXX $CUDAHOSTCXX"
	# 	# export CUDAARCHS
	# 	# export CUDAHOSTCXX
	# 	# unset NVCCFLAGS
	fi
}

multilib_src_compile() {
	:
	die
}

src_test() {
	:
# 	if use cuda; then
# 		cuda_add_sandbox -w
# 		local i
# 		for i in /dev/nvidia* /dev/dri/card* /dev/dri/renderD* /dev/char/ /proc/self/task; do
# 			addwrite "$i"
# 		done
# 	fi
#
# 	addpredict /dev/fuse

	die
}
