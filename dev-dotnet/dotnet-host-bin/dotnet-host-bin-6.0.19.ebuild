# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SDK="6.0.411"

DESCRIPTION="A generic driver for the .NET Core Command Line Interface (binary)"
HOMEPAGE="https://dotnet.microsoft.com/"
LICENSE="MIT"

SRC_URI="
amd64? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-x64.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-x64.tar.gz )
)
arm? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-arm.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-arm.tar.gz )
)
arm64? (
	elibc_glibc? ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-arm64.tar.gz )
	elibc_musl?  ( https://dotnetcli.azureedge.net/dotnet/Sdk/${SDK}/dotnet-sdk-${SDK}-linux-musl-arm64.tar.gz )
)
"

SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64"
QA_PREBUILT="*"
RESTRICT+=" splitdebug"

REQUIRED_USE="|| ( elibc_glibc elibc_musl )"

RDEPEND="
	app-crypt/mit-krb5:0
	dev-libs/icu
	dev-util/lttng-ust:0
	sys-libs/zlib:0/1
"

S=${WORKDIR}

src_install() {
	local dotnet_root="opt/dotnet"
	dodir "${dotnet_root%/*}"

	exeinto "${dotnet_root}"
	doexe dotnet

	insinto "${dotnet_root}"
	doins LICENSE.txt ThirdPartyNotices.txt

	echo "${EPREFIX}/${dotnet_root}" >> install_location
	insinto "/etc/dotnet"
	doins -r install_location

	dodir "/usr/bin"
	dosym "../../${dotnet_root}/dotnet" "/usr/bin/dotnet"

	# set an env-variable for 3rd party tools
	echo "DOTNET_CLI_TELEMETRY_OPTOUT=1" > "${T}/90dotnet" || die
	doenvd "${T}/90dotnet"
}
