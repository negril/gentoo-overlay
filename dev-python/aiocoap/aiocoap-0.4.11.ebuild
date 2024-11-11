# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )

DISTUTILS_USE_PEP517=setuptools
inherit distutils-r1 pypi

DESCRIPTION="The Python CoAP library"
HOMEPAGE="https://github.com/chrysn/aiocoap https://pypi.org/project/aiocoap/"
# SRC_URI="
# 	https://github.com/chrysn/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
# "

RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~riscv ~x86"
IUSE="oscore test tinydtls ws"
RESTRICT="!test? ( test )"

DOCS="README.rst"

RDEPEND="
	oscore? ( dev-python/cbor2[${PYTHON_USEDEP}] dev-python/cryptography[${PYTHON_USEDEP}] dev-python/filelock[${PYTHON_USEDEP}]  )
	tinydtls? ( >=dev-python/DTLSSocket-0.1.11_alpha1[${PYTHON_USEDEP}] )
	ws? ( dev-python/websockets[${PYTHON_USEDEP}] )
"
BDEPEND="
	test? (
		dev-python/pytest[${PYTHON_USEDEP}]
	)"

python_test() {
	py.test -v -v || die
}

distutils_enable_tests pytest
