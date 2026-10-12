# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} ) # Je nach deiner installierten Python-Version
DISTUTILS_USE_PEP517=setuptools

inherit distutils-r1 pypi

DESCRIPTION="Python library for detecting, parsing, and formatting numbered file sequences"
HOMEPAGE="https://github.com/rsgalloway/pyseq"

LICENSE="LGPL-3" # Prüfe die genaue Lizenz im GitHub Repository
SLOT="0"
KEYWORDS="~amd64 ~x86"

BDEPEND="test? ( dev-python/pytest[${PYTHON_USEDEP}] )"

distutils_enable_tests pytest
