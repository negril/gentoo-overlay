# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=poetry
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1 pypi

DESCRIPTION="ReactiveX for Python"
HOMEPAGE="http://reactivex.io/"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
