# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="8.0.303"

DESCRIPTION="ASP.NET Core runtime (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"

SRC_URI="
amd64? (
elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
)
"

S=${WORKDIR}

LICENSE="MIT"
SLOT="8.0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

RDEPEND="
	>=dev-dotnet/dotnet-runtime-bin-8.0.7:8.0
"

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	insinto "${dotnet_root}/shared"
	[[ -d "shared/Microsoft.AspNetCore.App" ]] && doins -r shared/Microsoft.AspNetCore.App
	[[ -d "shared/Microsoft.AspNetCore.All" ]] && doins -r shared/Microsoft.AspNetCore.All
}
