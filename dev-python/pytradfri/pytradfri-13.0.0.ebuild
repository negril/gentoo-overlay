# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )
DISTUTILS_USE_PEP517=setuptools
inherit distutils-r1 pypi

DESCRIPTION="IKEA Trådfri/Tradfri API. Control and observe your lights from Python."
HOMEPAGE="https://github.com/ggravlingen/pytradfri https://pypi.org/project/pytradfri/"
# SRC_URI="
# 	https://github.com/home-assistant-libs/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
# "

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc64 ~riscv ~x86"
IUSE="+async test"
RESTRICT="!test? ( test )"

RDEPEND="
	async? (
		dev-python/aiocoap[${PYTHON_USEDEP}]
		dev-python/DTLSSocket[${PYTHON_USEDEP}]
	)
	net-libs/libcoap[examples]
	dev-python/pydantic[${PYTHON_USEDEP}]

"

DOCS="README.md"

DEPEND="${DEPEND}
	test? (
		dev-python/pytest[${PYTHON_USEDEP}]
		dev-python/pytest-cov[${PYTHON_USEDEP}]
		>=dev-python/pytest-timeout-2.1.0[${PYTHON_USEDEP}]
		dev-python/flake8[${PYTHON_USEDEP}]
	)"

python_test() {
	py.test -v -v || die
}

distutils_enable_tests pytest
