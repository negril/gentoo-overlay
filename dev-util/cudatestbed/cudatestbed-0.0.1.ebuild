# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# inherit cmake cuda multiprocessing virtualx

inherit cuda

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

# pkg_setup() {
	# /opt/cuda-12.5.0/bin/__nvcc_device_query
# }

src_prepare() {
	eapply_user

	# mkdir -p "${S}"
	# cmake_src_prepare
}

src_configure() {
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

src_compile() {
	:
	# die
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
