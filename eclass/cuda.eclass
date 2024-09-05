# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: cuda.eclass
# @MAINTAINER:
# Gentoo Science Project <sci@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Common functions for cuda packages
# @DESCRIPTION:
# This eclass contains functions to be used with cuda package. Currently it is
# setting and/or sanitizing NVCCFLAGS, the compiler flags for nvcc. This is
# automatically done and exported in src_prepare() or manually by calling
# cuda_sanitize.
# @EXAMPLE:
# inherit cuda

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_CUDA_ECLASS} ]]; then
_CUDA_ECLASS=1

inherit flag-o-matic toolchain-funcs

# @ECLASS_VARIABLE: CUDA_REQUIRED_USE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# Requires at least one AMDGPU target to be compiled.
# Example use for CUDA libraries:
# @CODE
# REQUIRED_USE="${CUDA_REQUIRED_USE}"
# @CODE
# Example use for packages that depend on CUDA libraries:
# @CODE
# IUSE="cuda"
# REQUIRED_USE="cuda? ( ${CUDA_REQUIRED_USE} )"
# @CODE

# @ECLASS_VARIABLE: CUDA_USEDEP
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# This is an eclass-generated USE-dependency string which can be used to
# depend on another CUDA package being built for the same AMDGPU architecture.
#
# The generated USE-flag list is compatible with packages using cuda.eclass.
#
# Example use:
# @CODE
# DEPEND="sci-libs/rocBLAS[${CUDA_USEDEP}]"
# @CODE

# @ECLASS_VARIABLE: CUDA_SKIP_GLOBALS
# @DESCRIPTION:
# Controls whether _cuda_set_globals() is executed. This variable is for
# ebuilds that call check_amdgpu() without the need to define amdgpu_targets_*
# USE-flags, such as dev-util/hip and dev-libs/rocm-opencl-runtime.
#
# Example use:
# @CODE
# CUDA_SKIP_GLOBALS=1
# inherit cuda
# @CODE

# @FUNCTION: _cuda_set_globals
# @DESCRIPTION:
# Set global variables useful to ebuilds: IUSE, CUDA_REQUIRED_USE, and
# CUDA_USEDEP, unless CUDA_SKIP_GLOBALS is set.
# https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/

_cuda_set_globals() {
	# [[ -n ${CUDA_SKIP_GLOBALS} ]] && return

	if [[ -n ${CUDA_DEVICE_TARGETS} ]]; then
		local nvptx_device_targets_11_8=(
			# Kepler
			35 37
		)

		local nvptx_device_targets=(
			"${nvptx_device_targets_11_8[@]}"
			# Maxwell
			50 52 53
			# Pascal
			60 61 62
			# Volta
			70 72
			# Turing
			75
			# Ampere
			80 86 87
			# Ada Lovelace
			89
			# Hopper
			90 90a
			# # Blackwell
			# 100 10x
		)

		local nvptx_named_targets=(
			all
			all-major
			native
		)

		IUSE="${nvptx_device_targets[*]/#/nvptx_targets_sm_} +${nvptx_named_targets[*]/#/nvptx_targets_}"

		CUDA_REQUIRED_USE="
			?? (
				|| ( ${nvptx_device_targets[*]/#/nvptx_targets_sm_} )
				${nvptx_named_targets[*]/#/nvptx_targets_}
			)
		"

		local all_nvptx_targets=(
			"${nvptx_device_targets[@]/#/nvptx_targets_sm_}"
			"${nvptx_named_targets[@]/#/nvptx_targets_}"
		)

		local optflags="${all_nvptx_targets[*]/%/(-)?}"
		CUDA_USEDEP=${optflags// /,}

		for target in "${nvptx_device_targets_11_8[@]/#/nvptx_targets_sm_}"; do
			DEPEND+=" $(printf "%s? ( <dev-util/nvidia-cuda-toolkit-12.0 )" "${target}")"
		done
	fi
}

_cuda_set_globals
unset -f _cuda_set_globals

# == old stuff ==

# @ECLASS_VARIABLE: NVCCFLAGS
# @DESCRIPTION:
# nvcc compiler flags (see nvcc --help), which should be used like
# CFLAGS for c compiler
: "${NVCCFLAGS:=-O2}"

# @ECLASS_VARIABLE: CUDA_VERBOSE
# @DESCRIPTION:
# Being verbose during compilation to see underlying commands
: "${CUDA_VERBOSE:=false}"


# @FUNCTION: cuda_gccdir
# @USAGE: [-f]
# @RETURN: gcc bindir compatible with current cuda, optionally (-f) prefixed with "--compiler-bindir "
# @DESCRIPTION:
# Helper for determination of the latest gcc bindir supported by
# then current nvidia cuda toolkit.
#
# Example:
# @CODE
# cuda_gccdir -f
# -> --compiler-bindir "/usr/x86_64-pc-linux-gnu/gcc-bin/4.6.3"
# @CODE
cuda_gccdir() {
	debug-print-function ${FUNCNAME} "$@"

	local dirs gcc_bindir ver vers="" flag

	# Currently we only support the gnu compiler suite
	if ! tc-is-gcc ; then
		ewarn "Currently we only support the gnu compiler suite"
		return 2
	fi

	while [[ "$1" ]]; do
		case $1 in
			-f)
				flag="--compiler-bindir "
				;;
			*)
				;;
		esac
		shift
	done

	if ! vers="$(cuda-config -s)"; then
		eerror "Could not execute cuda-config"
		eerror "Make sure >=dev-util/nvidia-cuda-toolkit-4.2.9-r1 is installed"
		die "cuda-config not found"
	fi
	if [[ -z ${vers} ]]; then
		die "Could not determine supported gcc versions from cuda-config"
	fi

	# Try the current gcc version first
	ver=$(gcc-version)
	if [[ -n "${ver}" ]] && [[ ${vers} =~ ${ver} ]]; then
		dirs=( "${EPREFIX}"/usr/*pc-linux-gnu/gcc-bin/${ver%.*}*/ )
		gcc_bindir="${dirs[${#dirs[@]}-1]}"
	fi

	if [[ -z ${gcc_bindir} ]]; then
		ver=$(best_version "sys-devel/gcc")
		ver=$(ver_cut 1-2 "${ver##*sys-devel/gcc-}")

		if [[ -n "${ver}" ]] && [[ ${vers} =~ ${ver} ]]; then
			dirs=( "${EPREFIX}"/usr/*pc-linux-gnu/gcc-bin/${ver%.*}*/ )
			gcc_bindir="${dirs[${#dirs[@]}-1]}"
		fi
	fi

	for ver in ${vers}; do
		if has_version "=sys-devel/gcc-${ver}*"; then
			dirs=( "${EPREFIX}"/usr/*pc-linux-gnu/gcc-bin/${ver%.*}*/ )
			gcc_bindir="${dirs[${#dirs[@]}-1]}"
		fi
	done

	if [[ -n ${gcc_bindir} ]]; then
		if [[ -n ${flag} ]]; then
			echo "${flag}\"${gcc_bindir%/}\""
		else
			echo "${gcc_bindir%/}"
		fi
		return 0
	else
		eerror "Only gcc version(s) ${vers} are supported,"
		eerror "of which none is installed"
		die "Only gcc version(s) ${vers} are supported"
		return 1
	fi
}

# @FUNCTION: cuda_sanitize
# @DESCRIPTION:
# Correct NVCCFLAGS by adding the necessary reference to gcc bindir and
# passing CXXFLAGS to underlying compiler without disturbing nvcc.
cuda_sanitize() {
	debug-print-function ${FUNCNAME} "$@"

	local rawldflags=$(raw-ldflags)
	# Be verbose if wanted
	[[ "${CUDA_VERBOSE}" == true ]] && NVCCFLAGS+=" -v"

	# Tell nvcc where to find a compatible compiler
	NVCCFLAGS+=" $(cuda_gccdir -f)"

	# Tell nvcc which flags should be used for underlying C compiler
	NVCCFLAGS+=" --compiler-options \"${CXXFLAGS}\" --linker-options \"${rawldflags// /,}\""

	debug-print "Using ${NVCCFLAGS} for cuda"
	export NVCCFLAGS
}

# @FUNCTION: cuda_add_sandbox
# @USAGE: [-w]
# @DESCRIPTION:
# Add nvidia dev nodes to the sandbox predict list.
# with -w, add to the sandbox write list.
cuda_add_sandbox() {
	debug-print-function ${FUNCNAME} "$@"

	# /dev/char/195:0 -> ../nvidia0
	# /dev/char/195:254 -> ../nvidia-modeset
	# /dev/char/195:255 -> ../nvidiactl
	# /dev/char/226:0 -> ../dri/card0
	# /dev/char/226:128 -> ../dri/renderD128
	# /dev/char/240:0 -> ../nvidia-uvm
	# /dev/char/240:1 -> ../nvidia-uvm-tools
	# /dev/char/245:1 -> ../nvidia-caps/nvidia-cap1
	# /dev/char/245:2 -> ../nvidia-caps/nvidia-cap2

	if [[ ! -d /sys/module/nvidia ]]; then
		einfo "loading nvidia module"
		nvidia-modprobe || die
	fi

	if [[ ! -d /sys/module/nvidia_uvm ]]; then
		einfo "loading nvidia_uvm module"
		nvidia-modprobe -u || die
	fi

	local i WRITE

	# /dev/dri/card*
	# /dev/dri/renderD*
	# readarray -t dri <<<"$(find /sys/module/nvidia/drivers/*/*:*:*.*/drm -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's:^:/dev/dri/:')"
	readarray -t dri <<<"$(find -maxdepth 1 -regextype  egrep -regex ".*/(card|renderD)[0-9]*" -exec basename {} \; | sed 's:^:/dev/dri/:')"

	# /dev/nvidia{0-9}
	readarray -t cards <<<"$(find /dev -regextype sed -regex '/dev/nvidia[0-9]*')"

	WRITE+=(
		"${dri[@]}"
		"${cards[@]}"
		/dev/nvidiactl
		/dev/nvidia-uvm*

		# for portage
		/proc/self/task/
	)
	# for i in "${WRITE[@]}"; do
	# 	einfo "addwrite $i"
	# 	addwrite "$i"
	# done

	PREDICT=(
		# /dev/char/
		# /root
		# /dev/crypto
		# /var/cache/man
		# /var/cache/fontconfig
		# /proc/self/maps
		# /dev/console
		# /dev/random
		# /proc/self/task/
	)
	# for i in "${PREDICT[@]}"; do
	# 	einfo "addpredict $i"
	# 	addpredict "$i"
	# done

	for i in "${WRITE[@]}" ; do
		if [[ $1 == '-w' ]]; then
			einfo "addwrite $i"
			addwrite $i
		else
			einfo "addpredict $i"
			addpredict $i
		fi
	done
}

# @FUNCTION: cuda_toolkit_version
# @DESCRIPTION:
# echo the installed version of dev-util/nvidia-cuda-toolkit
cuda_toolkit_version() {
	debug-print-function ${FUNCNAME} "$@"

	local v
	v="$(best_version dev-util/nvidia-cuda-toolkit)"
	v="${v##*cuda-toolkit-}"
	ver_cut 1-2 "${v}"
}

# @FUNCTION: cuda_cudnn_version
# @DESCRIPTION:
# echo the installed version of dev-libs/cudnn
cuda_cudnn_version() {
	debug-print-function ${FUNCNAME} "$@"

	local v
	v="$(best_version dev-libs/cudnn)"
	v="${v##*cudnn-}"
	ver_cut 1-2 "${v}"
}

# @FUNCTION: cuda_src_prepare
# @DESCRIPTION:
# Sanitise and export NVCCFLAGS by default
cuda_src_prepare() {
	debug-print-function ${FUNCNAME} "$@"

	cuda_sanitize
}

fi

EXPORT_FUNCTIONS src_prepare
