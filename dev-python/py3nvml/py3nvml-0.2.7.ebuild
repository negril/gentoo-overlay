# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )

inherit cuda distutils-r1

DESCRIPTION="Python 3 bindings for the NVIDIA Management Library"
HOMEPAGE="https://github.com/fbcotter/py3nvml"
SRC_URI="https://github.com/fbcotter/py3nvml/archive/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~amd64-linux"

EPYTEST_PLUGINS=(
	hypothesis
)

distutils_enable_sphinx docs dev-python/sphinx-rtd-theme
distutils_enable_tests pytest

RDEPEND="
	x11-drivers/nvidia-drivers
"

python_test() {
	cuda_add_sandbox -w
	addpredict "/dev/char/"

	local num_gpus
	read -r -t 5 num_gpus <<< "$(nvidia-smi -L | wc -l)"

	if [[ "${num_gpus}" -eq 0 ]]; then
		die "No GPU found! Can't run tests."
	fi

	local EPYTEST_DESELECT=()

	if [[ "${num_gpus}" -eq 1 ]]; then
		EPYTEST_DESELECT+=( "tests/test_py3nvml.py::test_grabgpus2" )
		eqawarn "skipping tests/test_py3nvml.py::test_grabgpus2, requires two or more GPUs"
	fi

	if [[ "${num_gpus}" -lt 8 ]]; then
		EPYTEST_DESELECT+=( "tests/test_py3nvml.py::test_grabgpus4" )
		eqawarn "skipping tests/test_py3nvml.py::test_grabgpus2, requires eight GPUs"
	fi

	epytest
}

python_install_all() {
	if use doc; then
		local HTML_DOCS=( docs/_build/html/. )
	fi

	distutils-r1_python_install_all
}
