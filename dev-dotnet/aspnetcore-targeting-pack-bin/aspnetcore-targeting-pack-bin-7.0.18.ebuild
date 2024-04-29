# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="7.0.408"

DESCRIPTION="ASP.NET Core targeting pack (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"

SRC_URI="
	amd64? (
		elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
	)
"

S=${WORKDIR}

LICENSE="MIT"
SLOT="7.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	insinto "${dotnet_root}/packs"
	doins -r packs/Microsoft.AspNetCore.App.Ref
}
