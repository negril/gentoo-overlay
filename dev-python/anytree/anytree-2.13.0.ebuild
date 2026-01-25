# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
DISTUTILS_USE_PEP517=pdm-backend

inherit distutils-r1

DESCRIPTION="Powerful and Lightweight Python Tree Data Structure with various plugins"
HOMEPAGE="https://anytree.readthedocs.io/"

SRC_URI="https://github.com/c0fec0de/anytree/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

IUSE="dot"

RDEPEND="
	dot? (
		media-gfx/graphviz
	)
"

DEPEND="${RDEPEND}
	test? (
		$(python_gen_cond_dep '
			dev-python/pytest-cov[${PYTHON_USEDEP}]
			dev-python/test2ref[${PYTHON_USEDEP}]
		')
	)
"

PATCHES=(
	"${FILESDIR}/${PN}-2.13.0-move-RenderTreeGraph.patch"
)

distutils_enable_sphinx docs
distutils_enable_tests pytest

python_test() {
	local -x PYTEST_DISABLE_PLUGIN_AUTOLOAD=1

	local -x EPYTEST_DESELECT=()

	if ! use dot; then
		EPYTEST_DESELECT+=(
			"tests/test_dotexport.py::test_tree_png"
		)
	fi

	local -x PYTEST_PLUGINS="pytest_cov.plugin"

	distutils-r1_python_test
}
