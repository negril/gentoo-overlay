# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..14} )
inherit distutils-r1 pypi

DESCRIPTION="Python Bindings for the NVIDIA Management Library"
HOMEPAGE="http://developer.nvidia.com/nvidia-management-library-nvml"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
